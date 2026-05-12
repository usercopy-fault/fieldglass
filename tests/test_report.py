import json
from apdif.cases import create_case
from apdif.report import write_reports

def test_json_report(tmp_path):
    case=create_case('demo', tmp_path); r=write_reports(case); data=json.loads((case/'reports'/'report.json').read_text()); assert data['case']=='demo'; assert 'confidence' in data; assert r['json'].endswith('report.json')
