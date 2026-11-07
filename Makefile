.PHONY: build run test verify-notes
build:
	./script/build_and_run.sh --build-only
run:
	./script/build_and_run.sh
test:
	./script/test.sh
verify-notes:
	npm run verify-notes
