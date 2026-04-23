Java.perform(function () {
  const Log = function(msg) { console.log('[APDIF][baseline] ' + msg); };
  try {
    const WebView = Java.use('android.webkit.WebView');
    WebView.loadUrl.overload('java.lang.String').implementation = function (u) {
      Log('WebView.loadUrl(String): ' + u);
      return this.loadUrl(u);
    };
  } catch (e) { Log('WebView hook unavailable: ' + e); }
  try {
    const Intent = Java.use('android.content.Intent');
    Intent.setData.overload('android.net.Uri').implementation = function (u) {
      Log('Intent.setData: ' + u);
      return this.setData(u);
    };
  } catch (e) { Log('Intent hook unavailable: ' + e); }
});
