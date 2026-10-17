# CONTINUE: nerede kaldık

Bu dosya, son konuşmanın devamı için hazırlanmış bir devir notu. Terminalden (Claude Code CLI)
devam ederken önce bunu okut.

## 0. GÜNCEL DURUM (2026-10-17): GDD v4, önce bunu oku

Doğrudan `main` üzerinde çalışılıyor, PR yok. Sürüm `0.9.8`. Main.e push edilince workflow
`v0.9.8` release'ini kendisi açar. Aşağıdaki §1–§3 eski notlar.

- **Tasarım:** `docs/design/gdd-v4.md`. Araştırma: `docs/research/match3-meta-balance.md`.
  - Binalar kalıcı güç vermiyor; booster üretiyor.
  - Yıldız sadece bir dig'in ilk temizlenmesinden geliyor (kristal yıldız vermiyor).
  - Hamle başına coin kaldı.
- **4 booster** (`Economy.BOOSTERS`):

  | Booster | Üreten bina | Açılış |
  |---|---|---|
  | Bomba | Power | 8 yıldız |
  | Warp | Teleporter (bina indeksi 3, yeni) | 14 yıldız |
  | Lazer | Workshop | 20 yıldız |
  | Mıknatıs | Lab | 30 yıldız |

- **Üretim:** temizlenen dig başına. L1 5'te 1, L2 4'te 1, L3 3'te 1.
  - Bina toplanmamış booster varken yenisini üretmez (balon her zaman "1 hazır" demek).
  - `Game.made` / `collect` / `use_booster`.
  - Yeni kurulan bina ilk booster'ı hemen verir.
- **Dig:**
  - Altta `Widgets.BoosterBar`: kilitliler sadece kilit gösterir, basınca "Locked".
  - Tahta mekanikleri: `Board.use_booster`. Animasyonlar: `BoardView` step'leri `bomb`, `warp`,
    `laser`, `magnet`.
  - Hint ve Recall butonları kalktı. Tıkanan tahta kendiliğinden Pulse yapıyor.
  - Android geri tuşuna iki kez basınca dig'den çıkılıyor. Pause ve çıkış butonu yapılacak.
- **Koloni:**
  - Hazır booster binanın üstünde balon olarak çıkar; dokununca toplanıp DIG butonuna uçar.
  - Binaya dokununca zıplar (`ColonyView.poke`), kart 0.16 sn sonra açılır.
- **Bot:** `Bots.PLANNER` artık plan yapıyor: ulaşılabilir match'ler, pickup ve drill planlarını
  kopyada oynatıp hamle başına değere bakıyor.
  - Araçlar: `tools/bot_probe.gd` (dig başına bitirme oranı / kalan / kullanılan hamle;
    `sloppy`, `c3`/`c4`), `tools/balance_probe.gd` (upgrade alan ve tekrar deneyen oyuncu) ve
    `tools/tune_v4.gd` (tier'e göre bütçe bulur).
  - Rozet ve balon dokuları: `tools/art/badges.py`. Sayılar `Widgets.ink_text` ile ortalanır.
- **Performans:**
  - HUD ve tahta arasındaki layout döngüsü düzeltildi; bazı ekran oranlarında oyunu donduruyordu.
  - Ayarlar → FPS göstergesi.
  - DevShot `ASTRO_PERF=s` ve `ASTRO_HIDE=bar,hud,board,sky,fx`.
- **Yeni DevShot değişkenleri:**
  - `ASTRO_BOOST=b,w,l,m`: booster sayıları (-1 = kilitli).
  - `ASTRO_ARM=k` ve `ASTRO_USE=hedef` (`ASTRO_USEWAIT`).
  - `ASTRO_LOCKTAP=k`.
  - `ASTRO_MADE=p,w,l,t`.
  - `ASTRO_CARD=b` ile `ASTRO_TAPWAIT`.
  - Not: zsh'de birden fazla değişkeni `env ${=e}` ile ver.
- **5. adım YAPILDI (bölümler v4):** `docs/design/level-plan.md` v4 bölümü (tablo, yöntem,
  dersler). Her rastgele dig'de `tier` (intro / normal / hard / superhard / breather / reward)
  ve `colours` (3/4) var. Bütçeler `tools/tune_v4.gd` ile SLOPPY bota göre (`Bots.Kind.SLOPPY`).
  - 4. cevher Ruby (indeks 3); kristal 4'e taşındı (`Board.RES_CRYSTAL`).
  - Zor bölüm kartında "Hard Dig" / "Super Hard!" yazıyor.
- **İterasyon 1 (ilk 15 dig, yeni tempo):** `docs/design/level-plan.md` en üstte. Yeni dig'ler
  `quarry` (Bomba), `cellar` (hücre pratiği), `boulders` (2 katlı kaya). Power 10 yıldızda.
  Kullanıcı telefonda oynayacak; eğlenceliyse kalan dig'ler aynı tarzda, değilse çekirdek döngü
  sorgulanacak. Gezegen 1 uzunluğu (~60 dig önerisi) bu oynanıştan sonra kararlaştırılacak.
- **Çekirdek döngü prototipleri:** Ayarlar → Prototypes. A robot, B robot + düşen gem'ler (robot da
  düşer), C klasik swap. 5 ortak tahta, her biri farklı bir "hareket ettirilince çalışan" özel taş
  dener (drill, prism, geode, quake, blast). Ayrıntı: `docs/design/level-plan.md` en üstte. Bütçeler:
  `tools/tune_proto.gd`, `Sites.PROTO_ENERGY`. Kullanıcı hangisinin eğlenceli olduğuna karar verecek.
- **İterasyon 1b:** ilk 15 dig düşen gem modunda (prototip B kazandı). Power-up şekle göre: 4 düz →
  Matkap, L/T → Sarsıntı, 5+ düz → Prizma. **Zorluk kataloğu:** `tools/catalog.gd` →
  `docs/design/level-catalog.md` + `data/level_catalog.json`. Her değişiklikten sonra yeniden üret.
  Kalan dig'ler (16+) hâlâ robot modunda; oynanınca aynı kalıpla çevrilecek.
- **Sırada:** kombo juice (`docs/research/match3-combo-juice.md` kontrol listesi), Geode animasyonu.
- **Sırada (GDD v4 §5):**
  - `longhaul` Bomba öğreticisine dönüşecek. El yapımı dersler playtest edilmeli.
  - 6) Coin ile devam (+5 hamle, fiyatı artarak).
  - 7) Fiyatlar.
  - 8) Canlar.
  - 4. gem rengi (ruby, dig başına `colours` ayarı) karar verildi ama ölçülmedi ve yapılmadı.
  - Bot booster kullanmıyor; bu bilinçli, zorluk booster'sız ölçülüyor.

## 1. Repo durumu (eski)

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
1. ~~**Dig bütçelerini `Sites.gd`'ye yaz.**~~ **YAPILDI (2026-10-15).** Tablodaki bütçeler
   `Sites.gd`'de yazılı (merge PR #9 ile geldi, hepsi eşleşiyor). 45 hamleden uzun 4 dig'in
   düzeni sadeleştirildi (çok katmanlı kaya/kristal → daha az katman + açık zemin + yedek
   kristal/enerji hücresi):

   | dig | önce (medyan / planner) | sonra | değişiklik |
   |---|---|---|---|
   | stone | 54 / 43% | 12 / 100% | 2-katman stone'lar tek sıra yerine açık zemine dağıldı |
   | pockets | 50 / 26% | 25 / 88% | 3-kat basalt → 4× 1-kat kristal (hedef 3) + 2 enerji hücresi |
   | maze | 55 / 30% | 13 / 100% | 3-kat basalt inceltildi, kristaller 1-kat, 1 yedek + 1 hücre |
   | core | 45 / 46% | 17 / 84% | 3-kat basalt kabuk → 2-kat stone + gömülü hücre |

   `level-plan.md` güncellendi, testler 144/144. **Not:** `well` (56%) ve `rocks` (60%) hâlâ
   düşük (önceden de düşüktü, bu 4'lünün dışında); ileride ele alınabilir.
2. **Near-miss ekranı.** Enerji bitip hedef tamamlanmadığında:
   "Enerji bitti, şu kadar kaldı" mesajı + "+5 enerji" butonu (şimdilik ücretsiz, dig başına
   1 kez) + "Vazgeç" butonu. Buton `board.continue_with(5)` çağırır. İleride burası reklamlı ya
   da ücretli olacak. Yeri: `DigScreen._show_result`, `reason == "energy"` olduğunda.
3. **Hikâye metinleri.** ~~"match refunds energy" geçiyor.~~ **KISMEN YAPILDI (2026-10-15).**
   Yanlış iki tutorial satırı düzeltildi (`Sites.gd` longhaul + vaults, "Matches refill the
   battery" → bataryaya/enerji hücresine dayanan metin). Lab Lv3 "+1 enerji/eşleşme" metinleri
   (`Story.gd` 32/44, `Economy.gd` 26) mekanik olarak HÂLÂ doğru (`refund_bonus=1`), dokunulmadı.
   **KALAN (GDD v3 / bölüm 3):** Power Station metinleri (`Story.gd` 19-21) bataryanın dig
   uzunluğunu belirlediğini ima ediyor — artık `energy` anahtarlı dig'lerde bu yanlış (batarya
   kapasitesi bütçeye göre zaten büyüyor); batarya yalnız longhaul ve supply run için anlamlı.
   Power Station'ın yeni anlamı GDD v3'te tasarlanmalı.
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
- **KARAR (2026-10-15):** 2 para birimi — **Coin** (3 cevher türü tek Coin'e birleşir; renkler
  tahtada kalır, puzzle için) + **Star** (kristal + görev/performans). Homescapes/Royal Match
  modeli. 3 ayrı cevher bankası kaldırılacak.
- **KARAR (2026-10-15):** Power Station artık **her dig bütçesine +N enerji** ekliyor
  (önerilen +0/+3/+6/+10). Batarya kapasitesi zaten bütçeye göre büyüdüğünden eski "kapasite"
  upgrade'i yalnız longhaul/supply'da işe yarıyordu.

Benim önerdiğim sıra:
1. Kazı: enerji = hamle (YAPILDI, bölüm 2) + near-miss (ertelendi, kullanıcı isteği).
2. ~~GDD v3'ü yaz ve onaylat.~~ **ONAYLANDI (2026-10-15):** `docs/design/gdd-v3.md`
   (açık sorular doküman §9'da, inşaattan önce karara bağlanmalı).
3. Koloniyi Sliding Seas gibi görsel büyüyen bir yapıya çevir.
   - **FAZ 1+2 YAPILDI (2026-10-15): para birimi + Star-eşik unlock.**
     - `Game.gd`: `bank[4]` → `coin`/`star`. Save v2→v3 + eski kaydı taşıma (coin=ore toplamı,
       star=eski kristal + temizlenen dig sayısı).
     - `Economy.gd`: upgrade maliyetleri tek Coin int; `completion_bonus`→Coin int;
       `can_afford(coin,c)`; `cost()` -1 at max. Yeni: `STAR_MILESTONES=[4,8,14,20,30] (26 antenna site removed 2026-10-16)`,
       `STAR_UNLOCK=[8,20,30]` (power/workshop/lab), `POWER_BUDGET_BONUS=[0,3,6,10]`.
     - `Board.gd`: `rules.capacity`→`rules.budget_bonus`; dig bütçesi = `site.energy`(veya 20)
       + power bonus; opsiyonel `start` anahtarı (battery lesson düşük başlar).
     - `Sites.gd`: longhaul `energy:23`, battery `energy:20,start:9`.
     - `finish_dig`: coin += ore + enerji-fazlası; star += kristal + (ilk-temizleme? +1).
     - Unlock: `building_unlocked = star≥STAR_UNLOCK[b]`. L1 hâlâ ücretsiz "build" tıklaması
       (spotlight/pending_build UX korundu), L2/L3 Coin. Kampanya lineerliği eşiği needs-dig'den
       önce GARANTİ dolduruyor (econ_probe ile doğrulandı).
     - UI: ColonyScreen bank 2 `CurrencyChip` (Coin/Star), `CostRow` Coin, teaser "N★";
       DigScreen sonuç paneli Coin+Star; `Widgets.draw_currency_icon` + `CurrencyChip`;
       `Pal.COIN/STAR`. Story Power Station metinleri "+N enerji/dig".
     - `econ_probe.gd`/`simulate.gd` coin/star'a taşındı. Testler 144/144. Ekran görüntüsüyle
       koloni+dig doğrulandı.
   - **KOLONİ ÇEKİRDEĞİ YAZILDI (2026-10-16), art bekliyor.** Upgrade listesi kalktı.
     `scripts/core/Colony.gd`: harita plot'ları (normalize konum) + 6 milestone içeriği (3 bina,
     3 süs: pad/greenhouse/antenna). `Game`: `milestones_seen` (kayıtlı), `new_milestones()`,
     `ack_milestones()`, `next_milestone()`, `milestone_progress()`. `ColonyView`: üstten harita,
     kubbe + yollar + plot'lar, her plot bir buton (`plot_tapped`); bina/süs çizimleri GEÇİCİ.
     `ColonyScreen`: tek ekran (Coin/Star + `Widgets.MilestoneBar`, harita, Mira, DIG, debug satırı
     Log/Sound/Reset). Binaya dokun → kart (Build/Upgrade). Spotlight artık plot'u gösteriyor.
     Yeni milestone → harita kutlaması + süs için `Story.DECO` repliği. DevShot: `ASTRO_STAR`,
     `ASTRO_LEVELS=p,w,l`, `ASTRO_FRESH`, `ASTRO_CARD=b`. Testler 168/168.
     Mockup'lar (Layer, gemini): K1 059dd064…, K2 b58f1ad0…, K3 bfb96633… — kullanıcı henüz seçmedi.
   - **FAZ 3 ESKİ NOT:** kozmetik milestone görselleri. Şu an ColonyView yalnız bina seviyelerine
     bağlı ("Colony level N/9"). 3 kozmetik milestone (eşik 4/14/26) henüz görsel vermiyor;
     `Game.milestones_reached()` hazır. ColonyView'i milestone'lara bağla, Mira kutlama replikleri
     ekle, dig numarasını ("Dig N", "DIG · #N") UI'dan kaldır (debug-only).
4. Gezegen yapısı: 2. gezegenin tileset'i, cevherleri ve mekaniği; ilerleme yüzdesiyle geçiş.
   (Açık: Verdis mekaniği §9.3, gezegen % eşiği §9.4 — GDD v3'te hâlâ karar bekliyor.)
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

**ART v2 DURUMU (2026-10-16) — önce bunu oku.** Ayrıntı: `docs/art/art-direction-v2.md`.
- Master referans: `docs/art/ref-v2/env-hero.png` ("B1"). Gem ailesi `ref-v2/gems-family.png`,
  kaya `ref-v2/rock/base|crack|crumble.png`.
- Oyuna kurulu: gem'ler (`assets/ore/`), kaya state'leri (`assets/rocks/`), 3 tonlu yastık hücre
  (`assets/tiles/soil_a|soil_b|dent1|dent2|bare.png`; açık = kazılmamış, orta = 1, koyu = 2 kat).
  Kaynak hücre sheet'i Layer file `b66f5ead-6abb-4262-9a88-43906e998b1c` (muse, hero hücre
  kırpımları referans). Hücreler hero tonlarına color-match edildi, gölge alfadan üretildi.
- Board çerçevesi kodla: `BoardView._draw_board_frame()` tahtanın gerçek şeklini (bedrock hariç)
  izler; rim/parlama/koyu çizgi/dudak/gradyanlı zemin. Renkler `Pal.BOARD_*` (hero'dan pick).
- Öğrenilenler: yeşil zemin SERT eşikle keylenince kenar tırtıklanır → yumuşak alfa + despill +
  premultiplied küçültme kullan. Tile/ore/rock import'larında mipmap AÇIK; BoardView
  `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`. Kullanıcı her adımı motor ekran görüntüsüyle görmek
  istiyor (DevShot), Layer görsellerine değil motora güveniyor.
- Kalan art işleri: robot (hâlâ kod), HUD/butonlar (9-slice çerçeve + font metin), arka plan
  (B1 gibi gezegen), koloni (üstten bakışlı uzay kolonisi — yeni yön).
- Bu oturumda ~38 CU harcandı, bakiye ~228.

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
  - `ASTRO_MOVEWAIT=<saniye>`: hamleler arası bekleme.
  - `ASTRO_RESULT=complete|recall`: dig'i bitirip sonuç kartını açar.
  - `ASTRO_ENERGY=n`: kalan hamleyi n yapar (az hamle pulse'u için).
  - `ASTRO_DUMP=1`: görünen her Control'ün global rect'ini basar.
- El yapımı dig araçları:
  - `godot --headless --path . -s res://tools/replay.gd -- <id> <HAMLELER>`: hamleleri oynar,
    her adımda tahtayı basar.
  - `godot --headless --path . -s res://tools/handmade_probe.gd -- <id> [seed_from seed_to [runs]]`:
    greedy, planner ve %12 rastgele hamle yapan "sloppy" botla bitirme oranı; seed aralığı
    verilirse en iyi açılışı `ore` layout'u olarak basar.
- Çalışma kuralları:
  - Kullanıcıyla Türkçe konuş.
  - Her PR'da sürümü artır.
  - PR merge edilince branch'i `origin/main` üzerine al, `--force-with-lease` ile push et.

## 7. Bilinen açık sorunlar

- Çıkışta sızıntı raporu (zararsız, sadece oyun kapanırken). Fredoka fontu gelince başladı:
  ~16 satır `TextLine`, `ImageTexture`, glyph atlas ve GL texture "leaked" hatası. Font
  `.tres` resource olarak yükleniyor, `Art.clear_cache()` `Main._exit_tree`'de çağrılıyor,
  statik cache'ler temizleniyor; bunlar çözmedi. Sonra bakılacak.
