# Changelog

## [1.2.0](https://github.com/clinical-genomics-uppsala/wp3_validation_workflow/compare/v1.1.0...v1.2.0) (2026-05-05)


### Features

* add benchmarking report ([d78b3de](https://github.com/clinical-genomics-uppsala/wp3_validation_workflow/commit/d78b3de617fdd6c4a5f18a5920e86632f5fe9e69))
* add option to skip certain info field (e.g.; CSQ from vep) in vcf mdsum calc ([4f1e547](https://github.com/clinical-genomics-uppsala/wp3_validation_workflow/commit/4f1e5470c1d251ffd332b302ff04f70ee76cfb45))
* add option to skip the sample field in the vcf  md5sum calc ([8a30ea7](https://github.com/clinical-genomics-uppsala/wp3_validation_workflow/commit/8a30ea7842fcb76c669b2620d5d4878ba9d48372))
* use a python script for more robust vcf md5sum calculation ([6a125b1](https://github.com/clinical-genomics-uppsala/wp3_validation_workflow/commit/6a125b1161f8b5e7349729e085e9438ccb6f65b5))
* use script for report generation ([2e6e3ff](https://github.com/clinical-genomics-uppsala/wp3_validation_workflow/commit/2e6e3ff8c910819de03c7f7f3863caac42a4e139))


### Bug Fixes

* add mssing truvari script ([2940cf3](https://github.com/clinical-genomics-uppsala/wp3_validation_workflow/commit/2940cf351af83fd84a01f9fa443246a44f1289b5))
* convert input paths to absolute before chdir to temp_dir ([8ac4e5b](https://github.com/clinical-genomics-uppsala/wp3_validation_workflow/commit/8ac4e5b0af44d6f030cf85dea3f9788b7a2a4a1a))
* fix typo in create_validation_data ([7289be2](https://github.com/clinical-genomics-uppsala/wp3_validation_workflow/commit/7289be2cf0c34247c4c7b426bf32e8168d57ab88))
* fix typos in config names ([2c7b47f](https://github.com/clinical-genomics-uppsala/wp3_validation_workflow/commit/2c7b47fc8f424ee6cfc5f9127ed8a06e7a1d3dfe))
* move parameters tag to cell metadata for Quarto -P injection ([5d718e5](https://github.com/clinical-genomics-uppsala/wp3_validation_workflow/commit/5d718e540d126379d0ac30943c107a85a6aecbf9))
* resolve output_html to absolute path before chdir to temp_dir ([3ac6da4](https://github.com/clinical-genomics-uppsala/wp3_validation_workflow/commit/3ac6da4639c01aa89ff00d62ff39d025f9631819))
* small fixes including notebook path and md5sum file path ([07b7cca](https://github.com/clinical-genomics-uppsala/wp3_validation_workflow/commit/07b7ccad80ec7d59774cff4e9beaabecaa4eb8bc))
* update the nallo config ([013e221](https://github.com/clinical-genomics-uppsala/wp3_validation_workflow/commit/013e221485c6e2718deb7b26faf904a7de1b6656))

## [1.1.0](https://github.com/clinical-genomics-uppsala/wp3_validation_workflow/compare/v1.0.0...v1.1.0) (2026-03-02)


### Features

* add happy giab benchmarking ([90d56a1](https://github.com/clinical-genomics-uppsala/wp3_validation_workflow/commit/90d56a16982ecbf0bf56eebce649ba7c96bf941f))
* add truvari benchmarking ([baa391c](https://github.com/clinical-genomics-uppsala/wp3_validation_workflow/commit/baa391c56eb1f898677f43fe9889a8641a16e285))


### Bug Fixes

* add missing hg002 samples for happy benchmarking with more sample names ([c2c85af](https://github.com/clinical-genomics-uppsala/wp3_validation_workflow/commit/c2c85afe1d4fccca18b3ee6b7f2dc70d61ff2a67))

## 1.0.0 (2026-02-26)


### Features

* initial commit ([1b9b194](https://github.com/clinical-genomics-uppsala/wp3_validation_workflow/commit/1b9b1940c2523123bdc210e22cc48ce8148b9701))
