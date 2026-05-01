.PHONY: pull start clean reset

pull:
	docker compose --profile tools pull

start:
	chmod +x lab.sh
	./lab.sh

clean:
	docker compose down

reset:
	docker compose down -v
	rm -rf resultados/* reports/*
	touch resultados/.gitkeep reports/.gitkeep
