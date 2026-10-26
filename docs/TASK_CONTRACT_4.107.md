# TASK_CONTRACT_4.107 (AES-NUM-107)

Scope (from AES-NUM-106's NEXT + TODO 4.107):
(i) the camp-B label-pair correlation under a chance control — AES-NUM-106(iii) found, in camp B only (12 segments), label1 byte1 is an as-function hit of label2 byte0 and of label2 byte1 at label2's head slots (72 slot hits, determiner distinct 11, its collisions agreeing). Test: the exact non-vacuous as-function property (determiner distinct < n, every determiner collision agreeing on label1 byte1) in camp B, camp A, and pooled; then chance controls — seeded random subsamples of the pooled 25 of camp-B size (12), and seeded permutations of label1 byte1 over the pooled label2 values subsampled likewise — counting how often the non-vacuous property arises for byte0, byte1, either, and both;
(ii) the population-rare singleton words (fd000000, e9ff0000, f6000000) against wider segment populations beyond the 18 groups — aligned-word counts over all DISTINCT referenced segments of the corpus (keyed by artifact, offset, size; with reference multiplicities), a population strictly wider than the 18 groups' 102 instance segments and the 25 camp segments scanned in AES-NUM-106;
(iii) same-group instance-pair neighbourhood agreement at other common offsets — for every one of the 18 groups, every common offset, and every unordered pair of instances, the 5-word neighbourhood position-equal count (0–5); the distribution over all such triples, the target case ((MiniLM, 23, 32768) at 9272, cidx 3 vs cidx 5, 0/5) placed within it, and the distribution excluding that group/offset: is 0/5 the rule or an exception?

Host/artifact analysis only on Mimir — no physical child.

Corpus paths on Mimir: ~/.local/share/hailo-ollama/models/blob/sha256_* (6 HEF blobs) + MiniLM at ~/hailo10h-twister/custom-hefs/all-MiniLM-L6-v2-hailo10h/minilm-l6-ruvector.hef.

One bounded host-side child per contract.
