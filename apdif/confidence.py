CONTROL_WEIGHTS={'device-info':8,'permissions':10,'runtime-permissions':8,'appops':8,'apk-pulled':8,'package-dump':8,'static-strings':10,'manifest':8,'dynamic-logcat':8,'process-snapshot':6,'storage-inventory':8,'intent-hints':6,'frida-profile':8,'report':4}
SEVERITY_PENALTY={'info':0,'low':1,'medium':3,'high':6,'critical':10}
def assurance_class(score:int, completed:set[str]) -> str:
    if score < 25: return 'insufficient'
    if score < 55: return 'baseline-reviewed'
    if score < 80: return 'deep-reviewed'
    return 'high-confidence-in-scope' if {'device-info','permissions','apk-pulled','static-strings','dynamic-logcat','report'}.issubset(completed) else 'deep-reviewed'
def calculate_confidence(completed_controls:list[str], findings:list[dict]|None=None) -> dict:
    completed=set(completed_controls); coverage=sum(CONTROL_WEIGHTS.get(c,2) for c in completed); max_score=sum(CONTROL_WEIGHTS.values()); base=round(100*min(coverage,max_score)/max_score); penalty=sum(SEVERITY_PENALTY.get(str(f.get('severity','info')).lower(),0) for f in (findings or []) if f.get('status') not in ('fixed','false-positive')); score=max(0,min(100,base-min(penalty,20))); return {'score':score,'coverage_points':coverage,'max_points':max_score,'completed_controls':sorted(completed),'finding_penalty':min(penalty,20),'assurance_class':assurance_class(score, completed)}
