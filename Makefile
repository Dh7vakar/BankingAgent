.PHONY: install seed test ui api eval demo mcp
install:
	pip install -r requirements.txt
seed:
	python -m app.data.seed
test:
	python -m pytest -q
ui:
	streamlit run ui/app.py
api:
	uvicorn app.api.main:app --reload --port 8000
eval:
	python -m app.eval.runner
demo:
	python scripts/run_demo.py --print-only
mcp:
	python -m app.tools.mcp_server
