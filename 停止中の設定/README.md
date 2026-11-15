# 停止中の設定

## com.dotabata.autopublish.plist（2026-11-15に停止）

毎週月・水の朝9:00に、在庫の下書きから1本選んで自動公開する仕組み。

**止めた理由**：在庫33本がすべて1000字未満で、出すほど短い記事が増えるため。
公開済み159本のうち62本（39%）がすでに1000字未満で、AdSenseの
「有用性の低いコンテンツ」はここを見ている可能性が高い。
在庫は出さず、良いネタだけ今の書き方で書き直してから `yoyaku.sh` で出す、と決めた。

**もう一度動かすには**

    cp ~/my-blog/停止中の設定/com.dotabata.autopublish.plist ~/Library/LaunchAgents/
    launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.dotabata.autopublish.plist

`auto-publish.sh` 本体は残してある（`./auto-publish.sh --dry-run` で次の候補を見られる）。
個別予約（`com.dotabata.publish-MMDD`）と、Macの自動起動（月・水・金・土 8:50）はそのまま。
