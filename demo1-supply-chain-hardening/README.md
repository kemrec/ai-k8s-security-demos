# Demo 1 — Truva Modeli + Pod Sertleştirme (Supply Chain & Runtime)

**Güvenlik sorusu:** Bir AI serving pod'unu güvenmeden önce neyi doğrulamalıyız,
ve o pod ele geçirilirse patlama yarıçapını (blast radius) nasıl daraltırız?

Bu demo AI tedarik zincirinin **iki** katmanına dokunur ve sonra **runtime**
sertleştirmesini gösterir:

| Act | Katman | Ne gösteriyoruz |
|-----|--------|-----------------|
| 1 | Image (container) | Trivy ile CVE/secret taraması + SBOM üretimi |
| 2 | Model artifact | `pickle.load()` ile **kod çalıştırma** (OWASP LLM03) vs `safetensors` |
| 3 | Runtime (pod) | `naive` vs `hardened` pod — saldırgan ne kazanıyor? |

> GPU bağlantısı: GPU serving pod'ları çoğunlukla `/dev/nvidia*` erişimi için
> `privileged` çalıştırılır. Yani buradaki naive pod, gerçek bir GPU pod'unun
> birebir aynası. Sertleştirme reçetesi de aynıdır; GPU'da sadece
> `resources.limits: nvidia.com/gpu` (veya `nvidia.com/mig-1g.10gb`) ve tercihen
> `runtimeClassName: kata` eklenir.

## Ön koşullar
- Çalışan kind cluster (`../cluster/setup-kind.sh`)
- `kubectl`, `python3`
- İsteğe bağlı: `trivy` (image taraması için), `pip install safetensors numpy`

## Çalıştırma (tek komut)
```bash
./run-demo1.sh
```
Adım adım gitmek isterseniz:
```bash
# Act 1 — image supply chain
./trivy-scan.sh ollama/ollama:0.6.5

# Act 2 — model supply chain (bunlar tamamen local, cluster gerekmez)
python3 malicious_pickle_poc.py      # zehirli pickle -> kod çalışır (zararsız payload)
python3 safetensors_safe_demo.py     # safetensors -> aynı saldırı imkansız

# Act 3 — runtime
kubectl apply -f 01-ollama-naive.yaml
kubectl apply -f 02-ollama-hardened.yaml
MODEL=qwen2.5:0.5b ./verify-hardening.sh
```

## Sahnede vurgulanacak noktalar
- **Act 1:** Temiz bir image taraması, çalışma anında çekilen **model
  ağırlıklarını** garanti etmez. Image güvenliği ≠ model provenance. İkisi ayrı
  problemdir.
- **Act 2:** `pickle.load()` tek satır. `__reduce__` saldırganın döndürdüğü her
  callable'ı çalıştırır. Model sonrasında **kusursuz çalışır**, hiçbir şey
  anormal görünmez — JFrog'un Hugging Face'te bulduğu 100+ zararlı model tam
  olarak böyleydi. Çözüm: `safetensors`, imza doğrulama (cosign/Sigstore),
  modeli sandbox'ta yüklemek.
- **Act 3:** `naive` pod saldırgana **root + yazılabilir kök dosya sistemi +
  privileged** veriyor → container escape = node compromise. `hardened` pod aynı
  image ile modeli **hâlâ servis ediyor** ama saldırgana neredeyse hiçbir şey
  bırakmıyor. Sertleştirme fonksiyonellikten ödün verdirmedi; saldırgana ödün
  verdirdi.

## Sertleştirme kontrol listesi (manifest'te satır satır)
- `runAsNonRoot: true`, sabit `runAsUser` (root değil)
- `allowPrivilegeEscalation: false`, `privileged: false`
- `readOnlyRootFilesystem: true` (+ yazılabilir `emptyDir` yalnızca gerekli yollarda)
- `capabilities.drop: ["ALL"]`
- `seccompProfile.type: RuntimeDefault`
- `resources.limits` (DoS yarıçapını sınırla)
- Modelin önüne kimlik doğrulama koy (Ollama'da default auth **yok** —
  CVE-2025-63389)

## Temizlik
```bash
kubectl delete ns demo1
```
