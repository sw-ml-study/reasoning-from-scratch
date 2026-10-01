# CUDA transfer and graph experiment

A model-free Rust/cudarc probe tests the concrete hypotheses raised by the
[kernel trace](cuda-tracing.md). Device buffers are allocated once. Each
iteration performs the same800 affine kernels on1024 F32 values, synchronizes,
and copies607744 bytes to the CPU. Every value is checked exactly. The three
modes rotate order over64 repetitions; a second process repeats the experiment.
Compilation, capture and allocation are outside timing.

| Mode | Trial1 forward median | Trial2 forward median | Trial1 maximum transfer | Trial2 maximum transfer |
|---|---:|---:|---:|---:|
| Allocation-free launches, reused pageable buffer |1.1570ms|1.1713ms|6.183ms|19.559ms|
| Allocation-free launches, reused pinned buffer |1.1575ms|1.1736ms|30.375ms|0.184ms|
| Graph replay, reused pinned buffer |0.5516ms|0.5531ms|23.444ms|0.179ms|

Graph replay reduces median time for this fixed tiny-kernel sequence by about
**2.1×** in both trials. Reused pinned buffers do not consistently eliminate
transfer stalls: the first trial retains a30ms transfer, while the second
shows stable submillisecond transfers. Allocation-free ordinary launches also
retain occasional long forward spans. These observations narrow the experiment;
they do not establish a specific driver defect or a Qwen speedup.

The published v3 model provider is unchanged. Applying graph replay to its
Qwen path requires stable tensor addresses and cache shapes, likely an in-place
KV cache and a captured decode path, followed by numeric and supplied-uniform
acceptance. The current Candle implementation allocates/concatenates cache
storage and launches many individual kernels. Replaying the toy graph is not
a substitute for that implementation work. Pinned-transfer changes likewise
need repeated end-to-end acceptance before adoption.

[Trial1 rows](results/cuda-transport-v1.jsonl),
[trial2 rows](results/cuda-transport-v1-repeat.jsonl),
[first summary](results/cuda-transport-v1-summary.json) and
[repeat summary](results/cuda-transport-v1-repeat-summary.json) are retained.
The source archive `/disk1/tmp/reasoning-tools/cuda-transport-probe-source.tar.gz`
contains the independently authored probe and locked build instructions;
[hashes](results/full500-native-artifacts.sha256) pin source and executable.
No model weights, benchmark questions, MLPL interpreter or sampling run in
this probe. No further model optimization is claimed from it.
