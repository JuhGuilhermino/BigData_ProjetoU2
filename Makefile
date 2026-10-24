CXXFLAGS = -O2 -std=c++17 -Wall

all: main

main: src/main.cpp
	mpic++ $(CXXFLAGS) $< -o $@

cuda: src/kmeans_cuda.cu
	nvcc -O2 -std=c++17 -arch=native $< -o kmeans_cuda

pipeline:
	bash scripts/pipeline.sh

clean:
	rm -f main kmeans_cuda

.PHONY: all cuda pipeline clean
