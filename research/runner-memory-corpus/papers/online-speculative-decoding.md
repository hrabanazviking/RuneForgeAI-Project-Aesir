# Online Speculative Decoding — Adapting the Draft Model to Live Query Traffic

## 1. Full citation

- **Title:** Online Speculative Decoding
- **Authors:** Xiaoxuan Liu, Lanxiang Hu, Peter Bailis, Alvin Cheung, Zhijie Deng, Ion Stoica, Hao Zhang (UC Berkeley; UC San Diego; Sisu Data; Shanghai Jiao Tong University)
- **Venue / year:** Proceedings of the 41st International Conference on Machine Learning (ICML 2024), PMLR 235, pp. 31131–31146.
- **arXiv:** arXiv:2310.07177 [cs.AI] — submitted 11 Oct 2023; v4 10 Jun 2024 — https://arxiv.org/abs/2310.07177
- **Code (as reported in the paper):** https://github.com/LiuXiaoxuanPKU/OSD
- **Verification note:** this paper was verified at source (arXiv record + ICML proceedings record) on the access date. Version caution: the v1 arXiv abstract reports "1.22× to 3.06× latency reduction", while the final ICML / v4 abstract reports "1.42× to 2.17× latency reduction" for the same acceptance-rate gain (+0.1 to 0.65). This dossier cites the final-version headline and uses v1's experiment tables (the HTML full text available on arXiv) for detail, flagging where the two could differ.

## 2. The problem

Every other paper in this wave freezes its drafter at deployment: a draft model distilled offline, heads trained on ShareGPT, a feature head trained once. But speculative decoding's speedup is governed by the acceptance rate $\alpha$, and $\alpha$ is a property of the *match between the drafter and the actual input distribution*. Real services do not see "general text" — they see one domain's queries (one language, one topic mix, one house style), and that distribution *drifts* over time. A static drafter is therefore systematically mis-matched twice over: it was trained for the average case instead of this service's case, and it keeps yesterday's match while traffic moves. The capability gap between a small draft and a large target makes the mismatch expensive: offline acceptance rates in this paper's experiments start as low as 0.13–0.28 on some task/model pairs. Online Speculative Decoding (OSD) asks: since serving already reveals, for free, exactly where the drafter was wrong, why not keep training the drafter on live traffic?

## 3. Core idea / mechanism in our own words

**The free-supervision observation.** A speculative-decoding step already computes both distributions at the point of failure: the drafter proposed a token, the target's parallel pass produced the true distribution $p$ at that position, and the token was rejected. That (context, target distribution) pair is precisely a distillation training example targeting the drafter's current weakness — generated as a by-product of serving, at zero extra target-model cost. OSD simply *keeps* these pairs instead of discarding them.

**The loop.** Serve with ordinary speculative decoding (draft source: a small standalone draft model; $k=5$ proposed tokens per step in the experiments). Maintain a replay buffer $\mathcal{Q}$ of (context, target logits at the error position) records. Every $I$ requests (paper: $I=8$ in online experiments; tunable, and updates can be scheduled opportunistically when traffic is not spiking), take a gradient step on the draft model over the buffer, then clear it. The draft model therefore tracks the live query distribution continuously, including across distribution shifts.

**Training objective — online knowledge distillation (Generalised KD).** The draft (student) is aligned to the target (teacher) with a distribution-matching loss $D(p(\cdot|x) \| q_\theta(\cdot|x))$ summed over positions, instantiated as forward KL, reverse KL, or a JSD mixture, following the GKD framework (Agarwal et al.; Gu et al.). Two empirical findings matter: (1) distribution losses beat label fine-tuning on the teacher's sampled tokens — the full distribution carries more signal per example, which matters when examples arrive at serving rate; (2) *teacher sampling* (training sequences drawn from the teacher's distribution) beat student and mixed sampling in their offline comparison, and forward KL was the most reliable distance, with the best variant depending on the model pair/task. Gradients are estimated without differentiating through sampling (samples are plugged into the loss), keeping the update cheap and stable.

**Why it is (nearly) cost-neutral — the spare-FLOPs argument.** LLM serving is memory-bandwidth-bound, so serving clusters run at very low compute utilisation (the paper cites <1% on Arena chatbot traces). Draft updates are tiny next to target inference: FLOPs ratios of target:draft are 18.75× for the (Vicuna-7B, LLaMA-160M) pair and 12.6× for (FLAN-T5-XL 3B, T5-small 80M) pair. Updates therefore hide in compute that serving was wasting anyway; the scarce resource (bandwidth) is barely touched because the draft is small.

**Multiple specialised drafters.** The framework allows several draft models, each adapted to a cluster of the query distribution, with routing by input class. The real-workload experiment instantiates this as one LLaMA-160M drafter *per language* (top-5 non-English languages, all serving one Vicuna-7B target) and per-topic drafters for English.

**Distribution preservation.** Unchanged from classic speculative decoding: verification still uses the standard acceptance rule $\min(1, p/q_\theta)$ with residual resampling, so output remains exactly the target's distribution *regardless of how $q_\theta$ was trained*. Online training only moves $\alpha$; it cannot bias output, because the verifier corrects any draft, however adapted. (The converse also holds: a poisoned or over-fitted draft can only hurt speed, never correctness — a valuable safety property for learning-from-live-traffic designs.)

## 4. Design details an engineer needs

- **Model pairs evaluated:** Vicuna-7B target with LLaMA-160M draft; FLAN-T5-XL (3B) target with T5-small (80M) draft. Draft lengths $k=5$; online update interval $I=8$ requests.
- **Buffer policy is deliberately simple in the paper:** record the error index and target logits per request, append the request's records to $\mathcal{Q}$, train on all of $\mathcal{Q}$ at each update, then discard. Eviction/retention strategies (keep most-informative or most-recent) are named as future work — an implementer must choose a policy; unbounded retention is not viable in production.
- **Offline distillation is the warm start, not the competitor:** OSD pre-trains the draft on a warmup dataset, and its baseline for comparison is a draft distilled offline on 10% of the data and then frozen. Online adaptation starts *below* that baseline (less data seen) and catches up as traffic accumulates.
- **What gets learned is visibly distributional:** after adaptation, the largest precision/recall gains concentrate in the domain's signature tokens — SQL keywords (SELECT, WHERE, COUNT) on Spider; `<<`, `>>`, `=`, `+` scaffolding tokens on GSM8K; finance phrasing on Alpaca-finance. The top-100 most frequent target tokens account for 72.2% of token appearances in the Spider analysis: acceptance is a head-of-distribution game, and online training is aimed exactly at the head *of this service's* distribution.
- **Adaptation speed / shift behaviour:** under abrupt distribution shifts (concatenated datasets, boundaries at 2k/4k/6k records), $\alpha$ dips at each boundary and recovers quickly; OSD matches or beats static drafts distilled with 70–100% of the (future) data despite never seeing it in advance.
- **Systems integration costs to budget:** storing target logits per error position (vocabulary-sized vectors — the buffer is not free in memory), a training worker that must not contend with serving for bandwidth, draft weight versioning/swap-in without dropping in-flight requests, and a privacy posture for training on user queries (see Limitations).

## 5. Reported results — as reported, with context

All figures are the paper's own. Datasets: Spider (text-to-SQL), GSM8K (maths), Code-search-Python (code), Alpaca-finance (finance QA); plus real LMSYS Chatbot Arena conversations for the multi-drafter study.

**Headline (final ICML version abstract):** token acceptance rate increases by **0.1 to 0.65** across settings, translating to **1.42× to 2.17× latency reduction**. (The v1 abstract's wider 1.22–3.06× range reflects the earlier experiment set; the paper's §4.2.2 analysis, computed from its Table 1, gives expected speedup *improvements over static speculative decoding* of 1.22–2.42× for the Vicuna-7B pair and 1.55–3.06× for the FLAN-T5-XL pair across the four datasets.)

**Offline distillation ceiling (acceptance rate $\alpha$ after 2 epochs, forward KL; FT = label fine-tuning, TF/SF/MixF = teacher/student/mixed sampling):**

| Target | Task | Original draft $\alpha$ | FT | TF (best) | SF | MixF |
|---|---|---|---|---|---|---|
| Vicuna-7B (draft LLaMA-160M) | Spider | 0.28 | 0.74 | **0.76** | 0.62 | 0.70 |
| Vicuna-7B | GSM8K | 0.58 | 0.74 | **0.75** | 0.67 | 0.73 |
| Vicuna-7B | Code-Python | 0.38 | 0.65 | **0.65** | 0.51 | 0.61 |
| Vicuna-7B | Alpaca-finance | 0.57 | 0.68 | **0.67** | 0.63 | 0.65 |
| FLAN-T5-XL (draft T5-small) | Spider | 0.13 | 0.33 | **0.78** | 0.67 | 0.70 |
| FLAN-T5-XL | GSM8K | 0.29 | 0.50 | **0.62** | 0.51 | 0.55 |
| FLAN-T5-XL | Code-Python | 0.28 | 0.44 | **0.81** | 0.67 | 0.78 |
| FLAN-T5-XL | Alpaca-finance | 0.39 | 0.56 | **0.63** | 0.59 | 0.60 |

Read the Spider / FLAN-T5-XL row carefully: the *same draft model* goes from $\alpha$ 0.13 (near-useless) to 0.78 (excellent) purely by matching its training to the deployment distribution. That single row is the paper's thesis in miniature — and a warning that any wave-2 speedup figure quoted without its draft/target/data context is meaningless.

**Online setting:** starting from a 10%-data offline-distilled draft, OSD's moving-average $\alpha$ (last 50 requests) rises with traffic and reaches the offline ceiling in all four tasks, occasionally exceeding the offline *test-set* $\alpha$ (because the online average reflects the recent, narrower slice of traffic). On real Arena data, per-language drafters gained **+0.1 to +0.2 $\alpha$ with under 2k conversations per language** (Japanese easiest, Portuguese hardest); per-topic English drafters exceeded 0.6 $\alpha$ across topics, peaking near 0.8 for Social and Computer topics.

## 6. Limitations

- **It is a serving-cluster design.** The cost-neutrality argument leans on cluster spare FLOPs and continuous multi-user traffic. A single-user local deployment has neither the traffic volume to adapt quickly nor idle datacentre compute — adaptation still works mathematically, but the economics and timescales change completely (see §7a).
- **Privacy and data governance:** the method *trains on user queries by design*. In a hosted service that demands consent/retention policies; the paper does not address it. (For a purely local, single-user deployment the same property becomes a feature — the data never leaves the machine.)
- **Buffer/logit storage and update plumbing are real systems work**, and the paper's no-eviction buffer is a prototype choice, not a production policy.
- **Cold start and drift lag:** OSD starts below a good offline draft and dips at every distribution shift; workloads that change completely every few requests (a general-purpose API) give it nothing stable to learn. Its wins concentrate in *narrow, persistent* distributions.
- **Only small standalone drafters are studied** (160M / 80M). Whether the same online loop is stable and worthwhile for head-style drafters (Medusa/EAGLE), whose training dynamics differ, is not evaluated.
- Headline ranges differ between the v1 and final versions (see §1 note); cite the ICML figures.

## 7. Applicability

### (a) Ollama on a 6 GB GPU, single user, long chat

- **Reframe it: the "service" is one person's chat habits, and that is OSD's ideal distribution.** A single user's long-running character chat is about the narrowest, most persistent query distribution that exists — one persona, one voice, recurring topics and phrasing, for thousands of turns. The paper's per-language/per-topic specialisation result maps directly: one small draft, adapted to *this character, this user*, should reach acceptance rates a general offline draft cannot. And the privacy objection inverts: training happens on the user's own machine, on the user's own data, for the user's own benefit.
- **Where does the draft live in a 6 GB budget?** The paper's drafts are tiny (80–160M parameters — ~0.1–0.3 GB even at FP16, negligible at Q8/Q4), so residency is a non-issue next to a Q4 target; the real budget question is the *training* footprint: draft weights + gradients + optimiser state + a logits buffer. For a 160M draft with Adam that is on the order of 1–2 GB if held on GPU — too much beside a 7B target on 6 GB. The practical local design is: draft *inference* on GPU with the target; draft *updates* on CPU (or on GPU between sessions), infrequently, on accumulated session transcripts. A 160M model trains slowly-but-tolerably on CPU, and chat generates training data slowly too — the rates match.
- **The zero-training-data bootstrap already exists in the stack:** llama.cpp's n-gram speculation captures the *lexical* half of this adaptation (repeated phrasing) with no learning at all, and should be switched on first. OSD-style adaptation is the upgrade that captures the *distributional* half (which tokens this persona favours in fresh sentences). A sensible local roadmap: n-gram now → offline-distilled small draft (distil once on the user's own exported chat logs, the "10% warm start" made personal) → periodic re-distillation between sessions as logs grow. True per-8-requests online updates are over-engineering for one user; *session-granularity* online decoding is the same idea at the right clock speed.
- **Hard requirement carried over from the paper:** keep verification exact. Local adaptation must never be allowed to become "the draft is good enough, skip verification sometimes" — the moment verification is skipped, the user is chatting with the 160M draft, not their model.

### (b) Project Aesir

- OSD gives Aesir its drafter lifecycle policy: drafters are *living artefacts* with a training loop, a buffer, and an update cadence — not static files shipped once. Aesir's session layer should record (context, target distribution at rejection points) as a first-class by-product of speculative serving, behind an explicit per-user opt-in, stored locally.
- Aesir's idle-time scheduler is the local analogue of spare cluster FLOPs: when the device is plugged in and idle, run draft updates; when the user is actively chatting on battery/thermal limits, never train. Encode that as policy, not as a heuristic buried in the runner.
- Combine with EAGLE-3's lesson (eagle-3 dossier §7b): the strongest Aesir drafter is an EAGLE-style head trained with training-time test *and* refreshed online on the user's verified sessions. OSD supplies the refresh loop; EAGLE-3 supplies the architecture that benefits from more (personal) data.
- Safety property to preserve and advertise: because verification is exact, online adaptation can be rolled back, A/B'd, or disabled with zero effect on output correctness — only speed changes. Aesir should expose $\alpha$ per drafter version in its diagnostics so a bad adaptation is visible as a speed regression, never as a quality mystery.
- Multi-drafter routing maps to Aesir's character/session model: one adapted drafter per long-lived character/persona, selected by session, is the direct descendant of this paper's per-language drafters.

## 8. Access

- Date accessed: **2026-11-15**
- arXiv abstract: https://arxiv.org/abs/2310.07177
- arXiv HTML (read for method + evaluation detail): https://arxiv.org/html/2310.07177v1
- ICML 2024 proceedings record: https://proceedings.mlr.press/v235/liu24y.html
