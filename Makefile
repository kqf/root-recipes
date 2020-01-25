tests: tests.py
	pytest -s tests.py

tests.py: README.md
	excode README.md tests.py
	@# Change the default filename
	@sed -i.back 's/__main__/tests/g' tests.py
	@# Don't stop while testing
	@sed -i.back 's/stop=True/stop=False/g' tests.py

clean:
	rm *.py *.back

.PHONY: tests clean
