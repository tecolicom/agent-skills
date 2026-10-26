#!/bin/bash
# Claude Code MessageDisplay hook: show two texts in a reply side by side.
#
# A reply is shown unchanged unless its first line is a marker:
#   <!-- sxs -->        mdee -V: Markdown rendered, one boxed pane per text
#   <!-- sxs nup -->    nup -V: plain text, same boxed panes
#   <!-- sxs sdif -->   conflict markers + sdif -V: no boxes, corresponding
#                       paragraphs aligned (needs sdif)
# The text up to the second marker line `<!-- sxs -->` is the left pane,
# up to the third the right pane, and anything after a third marker is
# shown below the panes as it is.
#
# Settings (project .claude/settings.local.json or ~/.claude/settings.json;
# ~/.claude/settings.local.json is NOT read):
#   "hooks": { "MessageDisplay": [ { "hooks": [ { "type": "command",
#     "command": "SXS_PANE_WIDTH=91 $HOME/.claude/hooks/mdee-sxs.sh",
#     "timeout": 30 } ] } ] }
#
# Environment:
#   SXS_PANE_WIDTH   width of one pane; the output is twice this.  Inside a
#                    Claude Code reply at most (terminal columns - 5) fits,
#                    so use (columns - 5) / 2.  Default 80.
#   SXS_MODE         dark or light (default dark); the hook has no terminal,
#                    so the background cannot be detected
#   SXS_MDEE         the mdee command (default: mdee from PATH)
#   SXS_LEFT_COLOR, SXS_RIGHT_COLOR
#                    sdif text colors (Term::ANSIColor::Concise spec;
#                    default L22 and #E0B48C, no background)
#
# Requires jq, mdee 1.11 or later (--no-filename), nup, and sdif for the
# sdif mode.
marker='<!-- sxs -->'
pane=${SXS_PANE_WIDTH:-80}
mode=${SXS_MODE:-dark}
mdee=${SXS_MDEE:-mdee}

input=$(cat)
msg=$(jq -r .message_id <<<"$input") || exit 0
final=$(jq -r .final <<<"$input")
index=$(jq -r .index <<<"$input")
dir=${TMPDIR:-/tmp}/mdee-sxs
mkdir -p "$dir" || exit 0
log=$dir/log
find "$dir" -name '*.[0-9]*' -mmin +10 -delete 2>/dev/null
part=$dir/$msg.$index
jq -j .delta <<<"$input" > "$part.tmp" && mv "$part.tmp" "$part"

# is this an sxs message?  The first batch tells; later batches wait for it.
for ((t = 0; t < 30; t++)); do
    [[ -f $dir/$msg.0 ]] && break
    sleep 0.1
done
# the first line is `<!-- sxs -->` (mdee -V), `<!-- sxs nup -->` (nup -V,
# plain text) or `<!-- sxs sdif -->` (conflict markers + sdif -V, paragraphs
# aligned)
first=$([[ -f $dir/$msg.0 ]] && head -1 "$dir/$msg.0")
if [[ $first =~ ^\<!--\ sxs(\ (mdee|sdif|nup))?\ --\>$ ]]; then
    method=${BASH_REMATCH[2]:-mdee}
else
    [[ $final == true ]] && rm -f "$dir/$msg".*
    exit 0   # not an sxs message: show as usual
fi

printf '%s msg=%s index=%s final=%s\n' "$(date +%T)" "${msg:0:8}" "$index" "$final" >> "$log"
if [[ $final != true ]]; then
    echo '{"hookSpecificOutput":{"hookEventName":"MessageDisplay","displayContent":""}}'
    exit 0
fi
# wait for the earlier parts (batch hooks run concurrently)
for ((t = 0; t < 50; t++)); do
    missing=0
    for ((i = 1; i < index; i++)); do
        [[ -f $dir/$msg.$i ]] || { missing=1; break; }
    done
    (( missing )) || break
    sleep 0.1
done
md=$dir/$msg.md
for ((i = 0; i <= index; i++)); do
    [[ -f $dir/$msg.$i ]] && cat "$dir/$msg.$i"
done > "$md"
echo >> "$md"

# split at marker lines: left, right, and an optional postscript
left=$dir/$msg.left.md right=$dir/$msg.right.md post=$dir/$msg.post.md
awk -v L="$left" -v R="$right" -v P="$post" '
    /^<!-- sxs( (mdee|sdif|nup))? -->$/ { n++; next }
    n == 1 { print > L }
    n == 2 { print > R }
    n >= 3 { print > P }' "$md"
touch "$left" "$right" "$post"

# ANSICOLOR_NO_RESET_EL=1: no Erase Line after SGR reset.  The Claude Code
# renderer shows nothing for text containing CSI K.  Colors with an
# explicit E (h1, h2, code_block, FILE) still produce it in cat style;
# ansicolumn and sdif happen to leave none, but the output is filtered
# through s/\e\[\d*K//g below as a safeguard.
# code_mark=sub{""}: no ``` marks; displayContent is interpreted as Markdown
# and a fence inside a pane would swallow the layout.
# --no-filename: no file name label (mdee 1.11)
run_mdee() {
    env -u LINES -u COLUMNS ANSICOLOR_NO_RESET_EL=1 \
        "$mdee" -m "$mode" --cm 'code_mark=sub{""}' --no-filename "$@" </dev/null 2>>"$log"
}
# page height: count the folded lines of the longer side, then grow the
# page until both sides fit on one page (height includes the borders)
# conflict-marker format: the n-th blank-line separated block of the left
# text in one conflict with the n-th block of the right, so that sdif -V
# shows corresponding paragraphs on the same line
cm_join() {
    perl -e '
        sub blocks { local (@ARGV, $/) = (shift); grep { /\S/ } split /\n{2,}/, <> }
        my @l = blocks(shift); my @r = blocks(shift);
        my $n = @l > @r ? @l : @r;
        for my $i (0 .. $n - 1) {
            print "\n" if $i;
            print "<<<<<<< LEFT\n", $l[$i] // "", "\n=======\n", $r[$i] // "", "\n>>>>>>> RIGHT\n";
        }' "$1" "$2"
}
if [[ $method == sdif ]]; then
    out=$(cm_join "$left" "$right" |
          ANSICOLOR_NO_RESET_EL=1 sdif -V --no-filename --no-cdif --mark=no -W $(( pane * 2 )) \
              --cm "OTEXT=${SXS_LEFT_COLOR:-L22},NTEXT=${SXS_RIGHT_COLOR:-#E0B48C}" 2>>"$log" |
          perl -pe 's/\e\[\d*K//g')
    if [[ $out ]]; then
        printf '%s msg=%s sdif %s lines\n' "$(date +%T)" "${msg:0:8}" "$(wc -l <<<"$out" | tr -d ' ')" >> "$log"
        { printf '%s\n%s\n%s\n' '```text' "$out" '```'; [[ -s $post ]] && { echo; cat "$post"; }; } |
            jq -Rs '{hookSpecificOutput:{hookEventName:"MessageDisplay",displayContent:.}}'
    else
        jq -Rs '{hookSpecificOutput:{hookEventName:"MessageDisplay",displayContent:.}}' < "$md"
    fi
    rm -f "$dir/$msg".*
    exit 0
fi
# panes: mdee -V (Markdown rendered) or nup -V (plain text, same layout)
panes() {
    if [[ $method == nup ]]; then
        env -u LINES -u COLUMNS ANSICOLOR_NO_RESET_EL=1 \
            nup -V --pane=2 --no-pager --no-page-number -P "$1" "$left" "$right" -w $(( pane * 2 )) --no-filename </dev/null 2>>"$log"
    else
        run_mdee -V -w $(( pane * 2 )) -P "$1" --no-pager --no-page-number "$left" "$right"
    fi
}
n=0
for f in "$left" "$right"; do
    c=$(run_mdee -s cat --fold-width=$(( pane - 4 )) "$f" | ansifold -s -w $(( pane - 4 )) | wc -l | tr -d ' ')
    (( c > n )) && n=$c
done
h=$(( n + 3 ))
for ((t = 0; t < 6; t++, h += 2)); do
    out=$(panes "$h" | perl -pe 's/\e\[\d*K//g') || break
    pages=$(grep -c $'\xe2\x94\x8f' <<<"$out")   # one top border line per page
    (( pages <= 1 )) && break
done
if [[ ${out:-} ]]; then
    printf '%s msg=%s lines=%s page=%s pages=%s\n' "$(date +%T)" "${msg:0:8}" "$n" "$h" "$pages" >> "$log"
    # inside a code fence the Markdown renderer leaves the panes verbatim
    { printf '%s\n%s\n%s\n' '```text' "$out" '```'; [[ -s $post ]] && { echo; cat "$post"; }; } |
        jq -Rs '{hookSpecificOutput:{hookEventName:"MessageDisplay",displayContent:.}}'
else
    printf '%s msg=%s mdee failed, showing plain text\n' "$(date +%T)" "${msg:0:8}" >> "$log"
    jq -Rs '{hookSpecificOutput:{hookEventName:"MessageDisplay",displayContent:.}}' < "$md"
fi
rm -f "$dir/$msg".*
