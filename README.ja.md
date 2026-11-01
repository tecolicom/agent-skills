# tecolicom agent-skills

[English](README.md) | 日本語

tecolicom のコマンドラインツール用の [Agent Skills](https://agentskills.io) です。
スキルは、コーディングエージェント（Claude Code、Gemini CLI、GitHub
Copilot、Cursor、OpenCode など Agent Skills 対応のツール）に、これらの
ツールをいつ、どう使えば効果的かを教えます。

## 提供しているスキル

| スキル | ツール | 教える内容 |
|-------|--------|-----------|
| [greple](skills/greple/SKILL.md) | [App::Greple](https://github.com/kaz-utashiro/greple) | ブロック指向の検索: 関数や段落の中での AND 検索、ブロック全体の出力、領域を限定した検索、行をまたぐフレーズ検索 |
| [textconv](skills/textconv/SKILL.md) | [App::optex::textconv](https://github.com/kaz-utashiro/optex-textconv) | 任意のコマンド（cat、grep、diff、greple）に PDF、Office 文書、git オブジェクトをテキストとして読ませる |
| [dozo](skills/dozo/SKILL.md) | [App::dozo](https://github.com/tecolicom/App-dozo) | プロジェクトが想定する Docker イメージの中で、リポジトリをマウントしパスを保ったままコマンドを実行する |
| [side-by-side](skills/side-by-side/SKILL.md) | [App::ansicolumn](https://github.com/tecolicom/ANSI-Tools), [App::mdee](https://github.com/tecolicom/App-mdee), [App::sdif](https://github.com/kaz-utashiro/sdif-tools) | 2 つのテキスト（原文と訳文、2 つの版）を並べて表示する: ansicolumn -V、mdee -V、コンフリクトマーカーに対する sdif -V、行の対に対する cdif --lxl、エージェントの返信中のプレーンテキストや Markdown の表、Claude Code の返信中での MessageDisplay フックによる色付き表示 |
| [sdif](skills/sdif/SKILL.md) | [App::sdif](https://github.com/kaz-utashiro/sdif-tools) | 単語単位の差分と並列表示の差分（cdif、sdif、watchdiff）: 添削された原稿を単語ごとに確認する、日本語を MeCab の単語単位で比較する、単語の差分マークをエージェント向けにテキストで出力する |
| [ansi-tools](skills/ansi-tools/SKILL.md) | [App::ansicolumn, App::ansifold, App::ansiecho, Text::ANSI::Printf](https://github.com/tecolicom/ANSI-Tools) | ANSI の色や日本語を含むテキストを画面上の幅で揃える・折る・整形する: ansicolumn、ansifold（-r で段落を詰め直す）、ansiprintf、ansiecho、cat-v |

各スキルは、対応するツールが CPAN または Homebrew でインストール済みで
あることを前提にしています。

```sh
cpanm -n App::Greple                     # CPAN
brew install tecolicom/tap/app-greple    # Homebrew

cpanm -n App::optex App::optex::textconv          # CPAN
brew install tecolicom/tap/app-optex-textconv     # Homebrew

cpanm -n App::dozo                       # CPAN (Docker も必要)
brew install tecolicom/tap/app-dozo      # Homebrew

cpanm -n App::sdif                       # CPAN (日本語を扱うなら mecab も)
brew install tecolicom/tap/app-sdif      # Homebrew

cpanm -n App::ansicolumn App::mdee App::sdif                      # CPAN
brew install tecolicom/tap/app-ansi-tools tecolicom/tap/app-mdee tecolicom/tap/app-sdif   # Homebrew
```

### ツールをインストールしない方法: dozo と Docker

Docker と [dozo](skills/dozo/SKILL.md)（`cpanm -n App::dozo`、
`brew install tecolicom/tap/app-dozo`、または 1.02 以降の各
[リリース](https://github.com/tecolicom/App-dozo/releases)に添付されて
いる単一ファイル版。単一ファイル版は Bash 4.4 以上だけで動きます）が
あれば、これらのスキルのツールをホストにインストールせずに実行できま
す。`dozo -D` は dozo の既定イメージ（現在は `tecolicom/xlate`）の中で
コマンドを実行します。このイメージには greple、optex textconv、
sdif/cdif、ansicolumn、mdee、nup、mecab が入っています。

```sh
dozo -B -q -D env GREPLE_NORC=1 greple -n -e PATTERN file.md
dozo -B -q -D optex -Mtc cat document.docx
dozo -B -q -D env HOME=/tmp sdif -W 160 old.md new.md
```

各スキルにはこの方法について短い節があります。マウントされるのはリポ
ジトリ（またはカレントディレクトリ）なので、その外のファイルは見えま
せん。イメージ自身の設定が効かないように `HOME=/tmp` を指定します
（greple では `GREPLE_NORC=1`）。初回の実行では約 1 GB をダウンロード
します。

## インストール

### Claude Code

このリポジトリをプラグインのマーケットプレイスとして追加し、スキルを
プラグインとしてインストールします。

```
/plugin marketplace add tecolicom/agent-skills
/plugin install greple@tecolicom
```

### 更新

スキルにバージョン番号はなく、`main` の最新コミットが常に現行版です。
取り込むには、マーケットプレイスのクローンを更新してからインストール
済みのプラグインを更新し、Claude Code を再起動します。

```
/plugin marketplace update tecolicom
/plugin update greple@tecolicom
```

インストール後に追加されたスキルは新しいプラグインとして入れます:
`/plugin install ansi-tools@tecolicom`

### その他の Agent Skills 対応ツール

`SKILL.md` は [Agent Skills](https://agentskills.io) のオープン標準に
従っており、Claude 固有の拡張は含んでいません（side-by-side スキルには
Claude Code の表示フックに関する節が 1 つありますが、他の方法はどの
エージェントでも使えます）。スキルのディレクトリを、お使いのツールの
スキル置き場にコピーしてください。

```sh
# 場所はツールによって異なります。ツールのドキュメントを参照してください
cp -r skills/greple ~/.config/<your-tool>/skills/
```

正確なスキルディレクトリはツールのドキュメントで確認してください。
Gemini CLI、GitHub Copilot、Cursor、JetBrains Junie、OpenCode、
OpenHands などがこの形式に対応しています。

## 設計方針

レシピは、エージェント自身の能力に何を加えるかで選んでいます。

- **入れる**: エージェントが単独ではできないことを可能にする機能。
  ブロック指向の検索、領域を限定したマッチ、不可視文字の検出、
  Office ファイルの読み取り
- **入れる**: 何度も繰り返す検索と読み取りの往復を 1 つのコマンドに
  まとめる機能。共起（AND）検索、マッチを含む関数や節全体の出力
- **入れる**: 人間には面倒でもエージェントには自然なインターフェース。
  インラインの Perl 関数（`--cm 'sub{...}'`、`--callback`）や機械可読
  な出力など。エージェントはこうしたものを苦もなく生成します
- **入れる**: エージェントのコンテキストを守る機能。たとえば minify
  されたファイルや生成されたファイルを検索結果から除くこと。minify
  された CSS が 1 行マッチするだけで、出力は何千文字もの無意味な文字
  で埋まります
- **入れる**: 結果を人間が読むときに、エージェントが自分では正しく作
  れないレイアウト。たとえば CJK を考慮して折り返した 2 つのテキスト
  の並列表示。`column`、`paste`、`fold -s` は空白でしか折り返せず、
  それ以外のものは揃いません

次の 3 種類の機能は意図的に外しています。

- **モデル自身の能力の重複**: たとえば LLM バックエンドを呼ぶ翻訳モ
  ジュール。エージェントは自分で翻訳できます
- **人間のキータイプの節約**: コマンドのエイリアスや色付きの echo。
  入力の手間や画面上の見た目は人間の関心事で、エージェントには明示的
  で環境に依存しない形のほうが向いています
- **エージェントの既存ツールの重複**: 行番号によるテキストの選択。
  ファイル読み取りツールがすでにやっています。そもそも行番号は変わり
  やすい参照で、エージェントはコードを位置ではなく内容で探します

これらのスキルのレシピはすべて、文書化する前に実際のツールで検証して
います。

## 保守

- レシピは書く前に、インストール済みのツールで必ず検証する。再現性の
  ためのオプション（greple なら `GREPLE_NORC=1`）も含めて書く。
  「Recipes (all verified)」は約束
- 新しいスキルは `skills/NAME/SKILL.md`（frontmatter の `name` と
  `description`。description でエージェントがスキルを選ぶ）と
  `skills/NAME/.claude-plugin/plugin.json`、`.claude-plugin/marketplace.json`
  への登録、`README.md` と `README.ja.md` の表への行の 4 点。version
  フィールドは付けない（新しいコミットがインストール済みプラグインに
  届くように外してある）
- `main` への push がリリース。インストール済みのプラグインは次の更新
  で取り込む（「更新」参照）
- 告知する区切りでは GitHub Release を作る。タグはカレンダー版
  （`2026.11.01`、同じ日の 2 つ目は `2026.11.01.1`）、ノートは英語の
  後に `---` で区切って日本語。リリースは
  [www.tecoli.com/updates](https://www.tecoli.com/updates/) に載る

## ライセンス

MIT
