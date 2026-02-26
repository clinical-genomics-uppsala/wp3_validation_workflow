# Integration Test Makefile

.PHONY: test clean setup test-failures test-all

# Run the basic integration test (success case)
test:
	./run_test.sh

# Run failure detection test
test-failures:
	./test_failures.sh

# Run complete test suite (both success and failure tests)
test-all:
	./run_all_tests.sh

# Clean up test results
clean:
	rm -rf results/
	rm -rf results_failures/
	rm -rf checksums/
	rm -rf validation/
	rm -f correct_checksums.tsv

# Set up test environment (creates directories)
setup:
	mkdir -p results results_failures

# Run test with verbose output
test-verbose:
	./run_test.sh --verbose

# Generate checksums only (success case)
checksums:
	snakemake create_validation_data --configfile test_config.yaml --use-singularity --singularity-args "--bind $(shell pwd)" --cores 1

# Validate only (assumes checksums exist - success case)
validate:
	snakemake --configfile test_config.yaml --use-singularity --singularity-args "--bind $(shell pwd)" --cores 1

# Validate with expected failures
validate-failures:
	snakemake --configfile test_config_failures.yaml --use-singularity --singularity-args "--bind $(shell pwd)" --cores 1 --keep-going