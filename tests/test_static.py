from apdif.static import analyze_file

def test_static_scan_fake_sample(tmp_path):
    sample=tmp_path/'fake.apk'; sample.write_text('hello WebView addJavascriptInterface token=ABCDEFGHIJKLMNOPQRSTUV'); out=analyze_file(sample,tmp_path/'out'); assert out['strings_count'] >= 1; assert out['webview_indicators']; assert out['secrets']
