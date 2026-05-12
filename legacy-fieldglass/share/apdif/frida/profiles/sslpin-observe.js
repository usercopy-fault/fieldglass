Java.perform(function () {
  const Log = function(msg) { console.log('[APDIF][sslpin-observe] ' + msg); };
  try {
    const HttpsURLConnection = Java.use('javax.net.ssl.HttpsURLConnection');
    HttpsURLConnection.setDefaultHostnameVerifier.implementation = function(v) {
      Log('setDefaultHostnameVerifier invoked');
      return this.setDefaultHostnameVerifier(v);
    };
  } catch (e) { Log('HttpsURLConnection hook unavailable: ' + e); }
  try {
    const SSLContext = Java.use('javax.net.ssl.SSLContext');
    SSLContext.init.implementation = function(km, tm, sr) {
      Log('SSLContext.init invoked');
      return this.init(km, tm, sr);
    };
  } catch (e) { Log('SSLContext hook unavailable: ' + e); }
});
