build:
	@odin build src -out:bin/app

run: 
	@trap 'rm -f bin/temp' EXIT; \
	odin run src -out:bin/temp
