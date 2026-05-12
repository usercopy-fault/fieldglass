from apdif.confidence import calculate_confidence

def test_confidence_scoring():
    c=calculate_confidence(['device-info','permissions','apk-pulled','static-strings','dynamic-logcat','report'], []); assert c['score'] > 40; assert c['assurance_class'] in {'baseline-reviewed','deep-reviewed','high-confidence-in-scope'}
