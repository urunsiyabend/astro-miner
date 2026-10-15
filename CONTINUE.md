# CONTINUE: nerede kaldık

Bu dosya, son konuşmanın devamı için hazırlanmış bir devir notu. Terminalden (Claude Code CLI)
devam ederken önce bunu okut.

## 1. Repo durumu

- Branch: `claude/tender-ritchie-9meqga`. Açık PR: https://github.com/urunsiyabend/astro-miner/pull/9
  (merge edilmedi). Sürüm `0.8.2` (`project.godot` `config/version`, `export_presets.cfg`
  `version/code` 8002 ve `version/name`). Merge edilince otomatik release çıkar; sonraki PR'da
  sürümü yine artır.
- PR #9 içeriği:
  - Bölüm içinde kademeli zorlaşan level sırası. Dig 19 ve 29 düzeltildi
    (`docs/design/level-plan.md` v3).
  - Lacivert gece gökyüzü arka planı, bulanıksız.
  - Okunabilirlik: açık gri tonlar, bütün yazılarda kontur, en küçük font 30.
  - Tek plakada üst HUD, toplanan cevher için tek slot. Slota dokununca cevher dökümü açılıyor.
  - Boyalı kristal sprite'ı. Cevherler kutularına göre ortalandı (sarı üçgen artık hizalı).
  - Hedef çubuğu ikona değmiyor. Başlangıç kartında "Start" butonu var.
  - Koloni listesi kartın üstünden başlayan sürüklemeyle de kayıyor.
  - Gezegene göre tileset (`Art.planet`) ve 2. gezegen "verdis" tileset taslağı.
  - `tools/econ_probe.gd`, `tools/tune_moves.gd`.
- Testler: `godot --headless --path . -s res://tests/run_tests.gd` sonucu 144/144 geçiyor.

## 2. Yarım kalan iş: enerji = hamle (ONAYLI, devam et)

Kullanıcı onayladı: enerji casual match-3'teki "moves" sayacı gibi çalışacak.

**Yapıldı:**
- `Board.gd`: eşleşme enerji geri vermiyor (`refund_base`, `refund_extra` = 0). Her adım 1
  enerji yiyor; sadece enerji hücreleri ve Lab Lv3 bonusu enerji ekliyor.
- Dig'in `"energy"` anahtarı artık hamle bütçesi; batarya bu değeri alacak kadar büyüyor.
- `Board.continue_with(n)`: kaybedilen dig'e +n enerjiyle devam etmeyi sağlıyor.
  `stats.continues` sayılıyor. Testi var.
- `Bots.gd`: botlar eşleşmenin kendisine değer veriyor (`stats.groups * 2`). Eskiden bu teşviki
  enerji iadesi sağlıyordu; iade kalkınca botlar takılıyordu.
- El yapımı dig'lerin bütçeleri: battery 9, vaults 42, readings 42. Kayıtlı çözümler bu
  bütçelerle geçiyor.
- Uzun dig'lerin hedefleri küçültüldü:
  - ring: rock 5 + Ferrite 14
  - rooms: Cryo 12
  - deep: kristal 1 + Lumen 14
  - rubble: rock 9
  - strata: rock 6

**Yapılmadı (sıradaki adımlar):**
1. **Dig bütçelerini `Sites.gd`'ye yaz.** Şu an `energy` anahtarı olmayan dig'ler
   bataryayla (20 ya da 26) başlıyor, yani kampanya dengesiz. Önerilen bütçeler aşağıda.
   Kural şuydu: bütçe = min(botun kazandığı oyunların hedef yüzdesi, 2 × medyan), en az 15,
   en fazla 45.

   | dig | bütçe | dig | bütçe | dig | bütçe |
   |---|---|---|---|---|---|
   | drag | 20 | nearby | 16 | stone | 45 |
   | vein | 15 | checker | 32 | seam | 16 |
   | landing | 22 | route | 39 | rubble | 28 |
   | rocks | 32 | deep | 29 | strata | 39 |
   | glint | 16 | shallows | 30 | pockets | 45 |
   | ring | 26 | well | 30 | maze | 45 |
   | rooms | 27 | garden | 40 | shale | 34 |
   | zigzag | 35 | | | core | 45 |
   | lode | 15 | | | openseam | 22 |

   Ardından `tools/levels.gd -- 30` ile ölç. Şu dig'ler bot için 45 hamleden uzun:
   stone (medyan 54), pockets (50), maze (55), core (45).
   Bunlar kaya/kristal dig'leri; hedefi küçültmek yetmez, düzeninin (kaya sayısı ya da katmanı)
   sadeleşmesi gerekir. Casual hedef: dig başına 20–35 hamle, 2–3 dakika.
2. **Near-miss ekranı.** Enerji bitip hedef tamamlanmadığında:
   "Enerji bitti, şu kadar kaldı" mesajı + "+5 enerji" butonu (şimdilik ücretsiz, dig başına
   1 kez) + "Vazgeç" butonu. Buton `board.continue_with(5)` çağırır. İleride burası reklamlı ya
   da ücretli olacak. Yeri: `DigScreen._show_result`, `reason == "energy"` olduğunda.
3. **Hikâye metinleri.** `Story.gd` ve `Economy.gd` metinlerinde "match refunds energy" geçiyor.
   Lab Lv3 efekti (+1 enerji/eşleşme) ve Power Station'ın anlamı (batarya artık bütçeyi
   belirlemiyor) yeniden tasarlanmalı (bkz. bölüm 3).
4. Bütçeler yazılınca `tools/econ_probe.gd` ve `tools/levels.gd` ile tekrar ölç.
   `docs/design/level-plan.md`'yi güncelle, testleri çalıştır.

## 3. Kullanıcının oyun tasarımı kararları (GDD v3'ün temeli)

- **Kitle:** casual, Sliding Seas gibi. Otobüste oynanacak kısa oturumlar.
- **Gelir modeli (ileride):** enerji/can + near-miss (çoğu match-3 gibi).
- **Dig numarası sadece debug için.** "Dig 1, Dig 2" ileride kalkacak. Önemli olan koloniyi
  geliştirmek.
- **Koloni Sliding Seas gibi büyüyecek:** belli miktarda cevher getirildikçe görsel olarak
  büyüyen bir koloni. Mevcut meta döngüsü (3 bina × 3 seviye) sıkıcı bulundu.
- **Gezegenler:**
  - Her gezegenin kendi tileset'i, kendi cevher türleri ve yeni bir mekaniği olacak.
  - Bir gezegen tam bitmeden, belli bir yüzdeye ulaşınca sonrakine geçilebilecek.
  - Oyun şu an çok kısa (31 dig çabuk bitiyor), daha uzun olmalı.
- **Güçlendirmeler:** mevcut güçlendirmeler çok güçlü, oyuncuya çok hızlı verilmemeli.
- **Rota planlama:** tahtaların şekli rota planlamayı anlamlı yapmalı; şu an seviyeler hep
  aynı şekilde.
- **AÇIK KONU:** 3 cevher + kristal yerine 2 para birimi (cevher parası + yıldız).
  Kullanıcı "emin değilim" dedi. Araştırma 2 birimi destekliyor (Homescapes da yıldız + altın
  kullanıyor), ama karar verilmedi.

Benim önerdiğim sıra:
1. Kazı: enerji = hamle + near-miss (yarım; bölüm 2).
2. GDD v3'ü `docs/design/` altına yaz ve kullanıcıya onaylat.
3. Koloniyi Sliding Seas gibi görsel büyüyen bir yapıya çevir.
4. Gezegen yapısı: 2. gezegenin tileset'i, cevherleri ve mekaniği; ilerleme yüzdesiyle geçiş.
5. Seviye üretim aracı: bot çözücüyle yarı otomatik seviye üretip zorluğunu ölçmek.

## 4. Araştırma özetleri

**Ekonomi ölçümü** (`tools/econ_probe.gd`, eski iadeli kurallarla):
- Her dig'den 3 cevherden de eşit miktar geliyor, yani türlerin anlamı yok.
- 10. dig'de birikim ~140/140/130 cevher + 10 kristal. Oyunun bütün yükseltmeleri toplam
  230/220/190 cevher + 20 kristal; kazanılan, harcanabilecek olanın yaklaşık 2,5 katı.
- Kaynaklar (Lostgarden "value chains", Clash of Clans): her bina tek bir ana cevherle alınsın;
  fiyat = dig başı gelir × kaç dig'de alınması istendiği; seviye başı ×1,6–2 artış;
  tekrar edilebilir harcama yerleri (güçlendirme, koloni modülü); ödül dig başına sabit +
  yıldız/performans, toplanan taş sayısına göre değil.

**Casual oyun psikolojisi:**
- Quantic Foundry: Candy Crush oyuncusunda "tamamlama" güdüsü yüksek, strateji güdüsü düşük.
  Stres atmak en çok verilen sebep.
- Near-miss, kazanmaktan daha güçlü "devam et" isteği yaratıyor (Larche 2017). Ama çok zor
  seviyeler uzun vadede oyuncu kaybettiriyor (King, level 65 örneği).
  - Kaybedince ilerlemeyi dürüstçe göster, önce reklamlı/ücretsiz devam teklifi ver, fiyatı
    baştan açık yaz.
- Meta: ilk 100 match-3'ün yarısında yenileme ya da inşa var. Royal Match'te en hafif meta
  kazanmış: yıldız → görev → görünen değişiklik. Oyuncuya 2–3 tasarım arasından seçim sun.
- Oyuncu kaybettirenler: ani zorluk sıçraması, uyarısız yeni mekanik, yavaş başlangıç, çok sayıda
  para birimi.
  - İlk 20–30 seviye neredeyse garantili kazanılsın; koloni ilk 2 dakikada değişsin.
  - Seviyeler 2–3 dakika sürsün, ~5 seviyeden biri zor olsun.

**Mobil HUD:** üst bar hedefler ve hamle için; ikincil kaynaklar tek kompakt slotta, detay
seviye sonunda; cevher sayaca uçarak toplanır (bu yapıldı).

**Sliding Seas araştırması:** sonuç gelmeden konuşma bitti. Tekrar yap: koloni/ada nasıl
büyüyor, oyuncu bölümlerden ne getiriyor, ada başına kaç seviye var, sonraki adaya nasıl
geçiliyor, ekonomi nasıl.

## 5. Görsel üretim (Layer AI)

- Workspace `e8720ad0-ad91-44c4-aced-56252dafc5dc`, oturum `e4abc6ca-2bd0-4346-aa12-0527ac473244`.
  Ucuz model `muse-image`: 0,2 CU/görsel. 20 CU üstü işler kullanıcı onayı ister.
- **Kullanıcının uyarısı:** blockout'ları çok spesifik verdiğimiz için hep yanlış tarzda çıktı
  alıyoruz.
- Layer araştırması da bunu doğruluyor:
  - Muse bir düzenleme modeli; 0,8–0,9 init ağırlığıyla verilen düz blockout'u "bu resmi düzenle"
    diye okuyor, sonuç kaskatı çıkıyor. API'nin varsayılan init ağırlığı 0,5.
  - **Yeni yöntem:** onaylı lavanta tile'ı tek tek `init_image` olarak 0,4–0,6 ağırlıkla ver;
    "sadece malzeme ve renkleri değiştir" de; 2–4 lavanta tile'ı da stil referansı olarak ekle.
  - Ya da onaylı varlıklardan bir referans seti (Art Style reference set) oluştur ve sonraki
    gezegenleri ondan üret.
  - `tile_grid` (ALIGNED, elevation ~60–75) ve `export_tileset` de denenebilir.
- Dosya yükleme: `request_file_upload_url`, ardından POST (`x-goog-resumable: start`,
  `x-goog-content-length-range: 0,<tam boyut>`), sonra Location URL'ine PUT.
- **2. gezegen "verdis":** kullanıcı yeşil üst yüzü onayladı.
  - Şu anki taslak: nane yeşili üst yüz, sıcak kum rengi katmanlı yan yüz
    (`docs/art/sources/tiles_*_verdis.png`, `assets/tiles/verdis/`). Hiçbir dig henüz bunu
    kullanmıyor.
  - Üst yüzler hâlâ biraz soluk; yeni yöntemle yeniden üretilmeli.
  - Bu gezegene ait kayalar (yeşil damarlı) ve gökyüzü de lazım.
- Varlıklar `python3 tools/art/build_assets.py` ile kuruluyor. Gezegen listesi bu dosyadaki
  `PLANETS` değişkeninde.

## 6. Araçlar ve komutlar

- Godot 4.7.2 kullanılıyor.
- Testler: `godot --headless --path . -s res://tests/run_tests.gd`
- Seviye ölçümü: `godot --headless --path . -s res://tools/levels.gd -- 30 [id ...]`
  (planner bot bitirme oranı; el yapımı dig'ler için çözücü).
- Hamle bütçesi: `godot --headless --path . -s res://tools/tune_moves.gd -- 40 [id ...]`
- Ekonomi: `godot --headless --path . -s res://tools/econ_probe.gd`
- Ekran görüntüsü (xvfb):
  ```
  ASTRO_SHOT=out.png ASTRO_SCENE=dig|colony ASTRO_SITE=<index> godot --path . \
    --rendering-driver opengl3 --resolution 1080x1920
  ```
  Ek değişkenler:
  - `ASTRO_TALK=-1`: hedef kartı açık kalır.
  - `ASTRO_MOVES=UDLR`: verilen hamleleri oynar.
  - `ASTRO_HAUL=1`: cevher dökümünü açar.
  - `ASTRO_PLANET=verdis`: 2. gezegenin tileset'ini kullanır.
  - `ASTRO_CLEARED=n`: ilk n dig'i bitmiş sayar.
  - `ASTRO_MID=<saniye>`: ekran görüntüsünden önce bekler.
- Çalışma kuralları:
  - Kullanıcıyla Türkçe konuş.
  - Her PR'da sürümü artır.
  - PR merge edilince branch'i `origin/main` üzerine al, `--force-with-lease` ile push et.
