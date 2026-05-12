from apdif.cases import create_case, artifact_paths

def test_case_creation(tmp_path):
    p=create_case('demo case', tmp_path); assert p.exists(); assert (p/'case.json').exists(); assert 'reports' in artifact_paths('demo case', tmp_path)
