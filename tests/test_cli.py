from apdif.cli import main

def test_cli_help(capsys):
    try: main(['--help'])
    except SystemExit as e: assert e.code == 0
    assert '(cmd){options}[flags]' in capsys.readouterr().out
