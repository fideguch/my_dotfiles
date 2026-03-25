### プラグインマニフェストの注意点

`.claude-plugin/plugin.json` を編集する場合、Claude プラグインバリデータには**ドキュメント化されていない厳密な制約**がいくつかあり、曖昧なエラー（例: `agents: Invalid input`）でインストールが失敗することがあります。特に、コンポーネントフィールドは配列でなければならず、`agents` はディレクトリではなく明示的なファイルパスを使用する必要があり、`version` フィールドが必須です。

これらの制約は公開サンプルからは分かりにくく、過去に繰り返しインストール失敗の原因となりました。詳細は `.claude-plugin/PLUGIN_SCHEMA_NOTES.md` に記載されていますので、プラグインマニフェストを変更する前に確認してください。

### カスタムエンドポイントとゲートウェイ

ECC は Claude Code のトランスポート設定を上書きしません。Claude Code が公式 LLM ゲートウェイや互換カスタムエンドポイントを通じて実行されるよう設定されている場合、フック・コマンド・スキルは CLI 起動後にローカルで実行されるため、プラグインは正常に動作します。

トランスポート設定には Claude Code 自体の環境変数/設定を使用してください:

```bash
export ANTHROPIC_BASE_URL=https://your-gateway.example.com
export ANTHROPIC_AUTH_TOKEN=your-token
claude
```
