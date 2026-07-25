# Bonus — GPU Time-Slicing'in İzolasyon Vermemesi (gerçek GPU gerekir)

Bu **iki zorunlu local demonun parçası değildir**; GPU'lu bir makinede
göstermek isteyenler için ekstra.

**Mesaj:** Kubernetes'te GPU paylaşımının üç yolu vardır ve güvenlik açısından
eşit değildirler:

| Yöntem | Bellek izolasyonu | Fault izolasyonu | Ne zaman |
|--------|-------------------|------------------|----------|
| **Time-slicing** | ❌ yok | ❌ yok | Güvenilir/tek-tenant, yoğunluk için |
| **MPS** | ❌ zayıf | ❌ (bir client çökerse etkiler) | Güvenilen CUDA iş yükleri |
| **MIG** | ✅ donanım | ✅ donanım | Çok-tenant, SLA, izolasyon |

Time-slicing aynı fiziksel GPU'yu sırayla paylaştırır; VRAM sıfırlanmazsa bir
tenant'ın kalıntısı diğerine sızabilir. `vram_residue_check.py` bu fikri tek
process içinde (güvenli, taşınabilir) canlandırır.

```bash
pip install torch
python3 vram_residue_check.py
```

**Kubernetes çıkarımı:** çok-tenant izolasyon gerekiyorsa MIG kullanın
(`nvidia.com/mig-1g.10gb` gibi kaynaklar). Time-sliced/MPS GPU'ları **tek bir
paylaşımlı güven bölgesi** olarak kabul edin. Ayrıca kernel düzeyinde izolasyon
için `runtimeClassName: kata`/gVisor değerlendirin.

> Not: Ekosistem **DRA**'ya (Dynamic Resource Allocation) doğru gidiyor; NVIDIA
> DRA sürücüsü KubeCon EU 2026'da CNCF'e bağışlandı. Yeni GPU cluster'ları
> kurarken DRA'yı bilmekte fayda var.
