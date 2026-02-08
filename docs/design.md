# レシピ記録アプリ 設計メモ

## 目的
家庭や書籍、Webで得たレシピを個人資産として保存し、人数変更や振り返り記録で再現性を高める。

## 技術スタック
- Flutter 3.38.x
- ローカルDB: Hive
- 画像処理: image
- 共有: share_plus
- Zip入出力: archive + crypto
- 画面スリープ制御: wakelock_plus
- Markdown表示: flutter_markdown_plus

## データ構造

### Recipe
- id
- name
- genreId
- baseServings
- ingredients: Ingredient[]
- steps
- stepsFormat: markdown | marp
- coverImagePath: 仕上がり写真
- images: RecipeImage[]
- createdAt
- updatedAt

### Ingredient
- name
- quantity: 数値またはnull
- unit: 文字列

### RecipeImage
- id
- path
- caption

### CookingLog
- id
- recipeId
- date
- note
- photoPath

### Genre
- id
- name
- createdAt

### UnitDefinition
- id
- name
- usesNumber: 数値入力が必要な単位か

### AppSettings
- keepScreenOn
- defaultServings
- themeMode
- galleryMode
- sortAscending

## 画面構成

### レシピ一覧
- 検索、ジャンルフィルタ、表示モード切替
- リスト表示とギャラリー表示
- FABで新規作成

### レシピ詳細
- 仕上がり写真または参考画像
- 人数変更と材料の自動スケール
- 手順表示
- Markdownは縦スクロール
- Marpはページ切替ボタン
- 調理ログ一覧と追加
- 共有とZipエクスポート

### レシピ編集
- 料理名、ジャンル、基準人数
- 仕上がり写真の登録
- 材料はリスト表示
- 追加や編集はポップアップで入力
- 材料名は過去入力からサジェスト
- 単位は設定で管理した候補から選択
- 数値不要単位の場合は分量入力を無効化
- 手順は Markdown または Marp を選択
- 専用エディタで見出し、太字、箇条書き、ページ区切りをボタン入力

### 設定
- 画面消灯抑止
- デフォルト基準人数
- テーマ
- ジャンル管理
- 単位管理
- 全データ削除
- インポート
- アプリ情報

### ジャンル管理
- 追加、編集、削除

### 単位管理
- 追加、編集、削除
- 数値入力の有無を指定

## 保存とファイル構成
- HiveにRecipe, Log, Genre, Settings, Unitを保存
- 画像はアプリ内ドキュメント配下に保存
- images/recipes にレシピ画像
- images/logs にログ画像
- 保存時にVGAサイズのPNGへリサイズ

## インポート/エクスポート
- recipe.json と画像ファイルをZipで出力
- ハッシュ一致は取込スキップ
- 同名は上書き、別名、キャンセルを選択
- インポート時に不足単位は自動追加

## 重要な挙動
- 数値がない材料はスケール計算しない
- 仕上がり写真は1枚
- 参考画像は複数枚
- Marpは --- でページ区切り

## 今後の改善候補
- Marpプレビューのレイアウト調整
- 単位の並び替え
- 材料テンプレートの登録
