# CLAUDE.md

Claude Code için proje rehberi. Kullanıcıya dönük anlatım README.md'de; burası kural,
sözleşme ve gerekçe kaydıdır.

## Proje

Claude Code oturumlarının çalıştırdığı komutları ve çıktılarını terminalde gösteren tek
dosyalık Python CLI. Kaynak, oturumların kendi yazdığı transcript'ler:
`~/.claude/projects/<proje>/<session>.jsonl`. Araç yalnız okur.

```
.
├── agent-stream                # tek çalıştırılabilir; tüm kod burada (WebSink: --serve sunucusu)
├── bench/bench.py              # ölçüm takımı: boşta CPU, tarama, kare maliyeti
├── README.md                   # kullanıcı dokümanı (görünümler, bayraklar, ayar)
├── CLAUDE.md                   # bu dosya
├── config.example.toml         # ~/.config/agent-stream/config.toml örneği
├── LICENSE                     # MIT
└── .github/
    ├── checks.sh               # tutarlılık kontrolleri; lokalde de çalıştırılabilir
    └── workflows/lint.yml      # CI: py_compile + checks.sh
```

**Değişiklikten sonra çalıştır:** `./.github/checks.sh`

## Değişmezler

Bunlar bilinçli kararlar. Değiştirmeden önce burada neden yazdığına bak.

| # | Kural | Neden |
| --- | --- | --- |
| 1 | Araç salt okunur | Transcript'e yazma, hook kurma, oturum süreçlerine dokunma. Gözlemci bozarsa fatura Claude Code'a kesilir, hata orada aranır |
| 2 | Veri stdout, log stderr | Banner ve uyarılar `err_console`. `agent-stream --json \| jq` boru hattına banner karışmamalı |
| 3 | `--json` tam ve tamponsuz | NDJSON kırpılmaz, `print(..., flush=True)` ile basılır. Rich boru hattında tamponlar; kırpılmış JSON makineye yaramaz |
| 4 | Renk kararı tek yerde | `setup_console`: `--no-color` · `NO_COLOR` · `TERM=dumb`. Karar dağılırsa CI log'u ANSI çöpüyle dolar |
| 5 | Eşleme yalnız `tool_use_id` ile | Oturum araçları paralel çalışır; zaman damgasıyla eşleme yanlış çıktıyı yanlış komuta yapıştırır |
| 6 | Yeni dosya akışa **sonundan** katılır | `offsets[path] = st.st_size`. Aksi halde her yeni oturumda 10 MB'lık transcript ekrana boşalır. Geçmiş yalnız `--backfill` / `replay` ile |
| 7 | Süre transcript damgasından | Duvar saatinden değil; `replay` geçmişi doğru göstermek zorunda |
| 8 | Çıkış kodu sözleşmesi | `0` başarı · `1` hata · `2` kullanım hatası · `130` Ctrl+C. `EXIT_*` sabitleri tek kaynak |
| 9 | Kişisel yol sabit yazılmaz | Proje adı `HOME`'dan türetilir (`pretty_project`). Başka makinede de doğru okunmalı |
| 10 | Varsayılan **tüm araçlar** | Oturumun ne yaptığı yalnız Bash'ten okunmuyor; Read/Edit/MCP çağrıları da akışın parçası (kullanıcı kararı, 10.09). `-B/--bash-only` daraltır, `TodoWrite` her hâlükârda elenir |
| 11 | Ayar önceliği ölçülür, tahmin edilmez | `ctx.get_parameter_source` ile: bayrak > ortam > dosya > varsayılan (clig.dev) |
| 12 | İzleme olay tabanlı, yoklama **fallback** | Çekirdek uyandırır (kqueue/inotify); yoklama yalnız ikisi de kurulamayınca. Fallback opsiyonel değil: ağ dosya sistemleri ve BSD/Linux dışı ortamlar için tek çıkış yolu |
| 13 | Pano yalnız **değişiklikte** çizer | Durum değişmediyse kare üretilmez; koşan komut varken spinner için 4 fps, boşta 5 sn'de bir. Koşulsuz 8 fps %8,8 CPU tutuyordu |
| 14 | Ölçüm süreç **içinden** yapılır | `time.process_time`, sabit duvar penceresi. `RUSAGE_CHILDREN` yorumlayıcı açılışını da sayar ve boş kökte bile %1,9 gösterir |
| 15 | Ayar dosyası **her** alt komutta okunur | `merged_config(ctx)`: `[genel]` + alt komutun kendi bölümü. Yalnız `stream`'de okunması, `theme` yazan kullanıcıya panoda başka renk gösteriyordu |
| 16 | Bekleme sinyali **yalnız transcript'ten** | Süreç listesi, pencere başlığı, uygulama durumu okunmaz. `end_turn` + sonrasında insan satırı yok = bekliyor; oturum kapatılmış olsa da öyle görünür, bu kabul edilen yanlış pozitif (11.09) |
| 18 | Web sunucu **yalnız okur, yalnız dinler** | `--serve` SSE ile HTML parçası yayınlar; POST yok, telefondan oturuma yazma yok (1 numaralı kural). `0.0.0.0`'a bağlanır çünkü amaç telefon; kilit rastgele yol, başka her yol 404. Tailscale yok, ev ağı var (11.09 kullanıcı kararı) |
| 17 | `--json` her olayı `event` alanıyla verir | Notlar da NDJSON'a düşer; `.command` notlarda yok, tüketici `.command // empty` der. Notları ayrı bayrağa saklamak, zil/bildirim yazan betikleri iki akış dinlemeye zorlardı |

## Python Standartları

Tek dosya, PEP 723 inline bağımlılık bloğu (`rich`, `segno`), shebang `uv run --script`. Argüman
ayrıştırma stdlib `argparse` ile: typer tek başına açılışa 34 ms ekliyordu. Ağır modüller
(`rich.syntax`/pygments, `rich.live`, `rich.panel`, `ctypes`) kullanıldıkları fonksiyonun içinde
içe aktarılır; `--json` yolu pygments'i hiç yüklemez.
Yeni bağımlılık eklemek = shebang bloğunu güncellemek; `checks.sh` import ile listeyi karşılaştırır.
Kullanıcıya giden her metin Türkçe; kod yorumu da Türkçe ve tek satır.

| Yardımcı | Davranış |
| --- | --- |
| `die(msg, hint, code)` | `hata: …` + ipucu satırı stderr'e, `typer.Exit(code)` |
| `lane_of(sid)` | Oturum id'sinden sabit şerit rengi |
| `lane_print(console, color, renderable, marker)` | Rich renderable'ı satır satır basar, her satırın başına `▌` çubuğu koyar |
| `clip(s, n)` / `clean(text)` | Üç noktayla kırpma / system-reminder + ANSI + kontrol baytı temizliği |
| `human_dur(sec)` | `420ms` · `1.5s` · `2dk 3s` |
| `status_text(cmd, prefix)` | `✓ 1.5s · 15 satır` özeti |
| `Reader.poll(first, backfill)` | Bir okuma turu; `('start'\|'end', Cmd)` listesi döner |

## Görünümler

| Komut | Fonksiyon | Not |
| --- | --- | --- |
| `agent-stream` | `stream` (root callback) | Varsayılan. Komut çalışınca başlık + komut, bitince çıktı + özet |
| `agent-stream stream` | aynı fonksiyon, açık ad | `app.command("stream")(stream)` ile kayıtlı |
| `agent-stream dash` | `dash` | `Live(screen=True)`; oturum başına panel, çalışanda spinner, altta son 5 komut |
| `agent-stream wait` | `cmd_wait` | `seed_lanes` ile kuyruktan durum; bekleyenler önce (`Lane.order`), `--all` hepsi |
| `agent-stream sessions` | `sessions` | Etiket, proje, boşta kalma, boyut |
| `agent-stream replay <etiket>` | `replay` | Takip etmez; komut ve çıktısını eşli basar; notlar da düşer |
| `agent-stream stats` | `cmd_stats` | `--since` penceresinde tek geçiş; mtime ön filtresi + damga filtresi |

## Olay Türleri

`Reader.poll` iki sınıf üretir: `Cmd` (`start`/`end`) ve `Note`. Her ikisi `Keyed`: `key`
(oturum + subagent), `tag`, `lane` ortak. Durum makinesi `apply(lanes, kind, ev)` tek yerde;
pano, `wait` ve `seed_lanes` aynı fonksiyonu çağırır.

| kind | kaynak satır | `apply` etkisi |
| --- | --- | --- |
| `human` | `type=user`, `origin.kind=human`, içerik string | `prompt`, bekleme sıfırlanır, `loop=False` |
| `fire` | `type=user`, `origin` yok, içerik `<command-message>` | `loop=True`; sonraki `turn` beklemez |
| `ask` / `answer` | `AskUserQuestion` ya da `ExitPlanMode` `tool_use` / eşleşen `tool_result` | `waiting="ask"`, `ask` notu; cevapta sıfır |
| `turn` | `type=assistant`, `stop_reason=end_turn`, metin bloğu olan satır, sidechain değil | `waiting="turn"`; `extra.loop` ya da `extra.bg` ise beklemez, yalnız `turn` metni |
| `fire` (task) | `origin.kind=task-notification` | `loop=True`, `bg` sayacı bir düşer |
| `ctx` | her `assistant` satırındaki `usage` toplamı (input + cache_read + cache_creation) | `ctx`, `model`; akışta basılmaz, pano/wait çubuğu |
| `compact` | `isCompactSummary` ya da `system/compact_boundary` | yalnız akışta satır |
| `apierr` | `system/api_error` | `warn`; sonraki `start` siler |

## İzleyici Katmanı

Üçü de aynı sözleşme: `sync(dirs, files)` izlenecek kümeyi kurar, `wait(timeout)` bir şey olana
kadar bloklar ve `(uyandı mı, tarama gerekli mi)` döner, `close()` biriktirdiği fd'leri bırakır.

| Arka uç | Nerede | Ne izler | Not |
| --- | --- | --- | --- |
| `KqueueWatcher` | macOS/BSD | dizinler + takip edilen dosyalar | Dosya başına fd gerekir; `WATCH_CAP` üst sınır |
| `InotifyWatcher` | Linux | yalnız dizinler | İçindeki dosyaların olayı adıyla geldiği için dosya izlemeye gerek yok; libc'ye ctypes ile bağlanır, bağımlılık eklemez |
| `PollWatcher` | her yer | hiçbir şey | Uyur; tarama zamanlamasını `Reader` yapar, boşta kaldıkça aralık `IDLE_STEPS` merdiveninden büyür |

`make_watcher()` sırayla dener, kurulamayanı sessizce atlar; `AGENT_STREAM_WATCH` ile zorlanır.
Olay arka ucunda güvenlik taraması 30 sn'de bir (`EVENT_RESCAN`), yoklamada 5 sn (`SAFETY_RESCAN`).

## Savunma Satırları

Koddaki tek satırlık yorumların uzun gerekçesi. Bu satırları sadeleştirmeden önce oku.

| Yer | Satır | Neden orada |
| --- | --- | --- |
| `lane_print` | `console.print(Segments([bar, *line, Segment("\n")]), end="")` | Rich'te `print(a, b)` iki renderable'ı ayrı blok basar, çubuk kendi satırına düşerdi. Newline'ı segment listesine elle koymak satırı bir arada tutan tek yol |
| `lane_print` | `first` / `rest` çubukları | Komutun `$` işareti çubuğa biner; sarılan satırlar aynı kolondan devam eder |
| `StreamView.end` | `if cmd.uid != self.last_uid` | Paralel araç çağrılarında çıktı başka komutun başlığı altına düşüyordu; `↳` ile yeniden çapalanır |
| `cmd_block` | `max_cmd` kırpması | Heredoc'lu komutlar 60+ satır olabiliyor; `-q` çıktıyı kapatsa bile ekranı komut bloğunun kendisi dolduruyordu (10.09'da canlı akışta görüldü) |
| `StreamView.end` | `self.c.file.flush()` | Rich boru hattında tamponlar; `agent-stream \| grep` canlı kalmalı |
| `Reader.poll` | `'"tool_use"' not in line` ön elemesi | 10 MB'lık transcript'te satır başına `json.loads` pahalı; ilgisiz satırlar string testiyle elenir |
| `Reader.poll` | `lines[-backfill * 6:]` + keep-set | Bir komut birkaç JSONL satırı eder; kaba pencere alınıp sonunda olay sayısına indirilir |
| `Reader.files` | `subagents/**` glob'u | Subagent'lar ana transcript'e yazmıyor, `<proje>/<oturum>/subagents/agent-*.jsonl` altında ayrı dosyalarda duruyor. Eski glob (`*/*.jsonl`) onları hiç görmüyordu; `--no-subagents` bayrağı da bu yüzden boşa çalışıyordu (10.09) |
| `Reader._walk` | `scandir` + `FRESH` filtresi | Özyinelemeli `glob` 2.202 dosyada 20,4 ms tutuyordu; `scandir` 10,9 ms, yedi günden eski proje dizinlerine hiç inmemek 7,2 ms |
| `Reader.files` | `full = ... > self.rescan` | Ara turlarda yalnız takip edilen dosyalara `stat` atılır. Tam tarama olay arka ucunda 30 sn'de bir yeter: yeni dosyayı dizin olayı zaten söylüyor. 5 sn'de bir taramak boşta CPU'yu %0,04'ten %0,17'ye çıkarıyordu |
| `InotifyWatcher.sync` | yalnız dizinleri izler | Linux'ta bir dizin izlendiğinde içindeki dosyaların `IN_MODIFY` olayları da adıyla geliyor; dosya başına watch açmak gereksiz ve pahalı olurdu |
| `InotifyWatcher._drain` | `struct.unpack_from("iIII")` | inotify olayı 16 baytlık başlık + hizalanmış ad; `len` alanı okunmadan bir sonraki olaya atlanamaz |
| `highlight` | `_HL` önbelleği | Pygments boyaması şerit başına 0,55 ms; pano saniyede 4 kez çiziyor. Önbellek tema değişince temizlenir |
| `dash_frame` | `parts` tek geçişte | Yükseklik ölçümü ve çizim aynı `lane_parts` sonucunu kullanır; iki kez hesaplamak kare maliyetini 12 ms'den 4,9 ms'ye düşürdü |
| `Reader.files` | Stale filtresi yalnız **yeni** dosyaya | Takip edilen bir oturum sessizleşince akıştan düşmemeli |
| `cmd_block` / `lane_panel` | `theme=THEME`, varsayılan `monokai` | `ansi_dark` rengi terminal paletinden alıyordu: tek renkli bir profilde (yeşil üstü siyah gibi) komutun her parçası aynı tonda çıkıyor, boyama bilgi taşımıyordu. Sabit tema iki terminalde de aynı; palet mirası isteyen `--theme ansi_dark` der |
| `clip` | `cell_len` / `set_cell_size` | `len()` karakter sayıyordu: emoji ve CJK iki hücre kaplar, `🔴 …  ✅` satırı 36 karakter ama 38 hücre. Sarma noktası kayıp satır taşıyordu |
| `head_text` | Açıklama başlık satırında | Ayrı `· açıklama` satırındayken blok altında kalıyordu; `-q` modunda bile ekranı heredoc gövdesi dolduruyor, ajanın ne yaptığı okunmuyordu (10.09 ekran görüntüsü) |
| `dash_frame` | Yükseklik en dolu şeride göre | Sabit yükseklikte kısa çıktıda ekran boyu ölü boşluk kalıyordu; içeriğe göre panel panel değişse şeritlerin altı hizasını kaybeder ve her çıktı satırında düzen zıplardı. Ortası: hepsi eşit, en dolu şeridin ihtiyacı kadar |
| `pretty_tool` | `UUID` sunucu adı → `mcp:` | Konnektör MCP sunucuları 36 karakterlik uuid adı taşıyor; ham hâli komut satırının yarısını yiyordu |
| `_result` | `"stdout" in tur` koşulu | `toolUseResult` yalnız Bash'te `stdout`/`stderr` taşıyor; Read/Edit/MCP sonuçları `tool_result` bloğunda. Koşulsuz `tur.get("stdout")` bütün Bash dışı araçlara "çıktı yok" dedirtiyordu (10.09, tüm araçlar varsayılan olduktan sonra görüldü) |
| `clean` | `SYSREM` deseni | `tool_result` içine eklenen `<system-reminder>` blokları kullanıcının komut çıktısı değil |
| `parse_ts` | `.replace("Z", "+00:00").astimezone()` | Transcript UTC yazar; ekranda yerel saat okunur |
| `lane_panel` | Komut satır satır, `max_cmd` ile kırpık | İlk tasarım satır sonlarını ` ⏎ ` ile birleştirip tek satıra sıkıştırıyordu; heredoc'lu komutlar şeritte okunmaz oluyordu (10.09 panoda görüldü) |
| `lane_panel` | Çıktı kuyruğu komutun hemen altında | Dibe yapıştırılınca (ilk tasarım) uzun terminalde komut ile çıktısı arasında ekran boyu boşluk kalıyordu; kuyruk yine son satırlar, ama başlığa bitişik |
| `lane_panel` | `Panel(..., width=width)` | Genişlik verilmezse `Columns` panelleri yan yana değil alt alta yığar |
| `lane_panel` | Spinner gövdede, özet altyazıda | `Panel(subtitle=…)` yalnız metin kabul eder; `Columns` altyazıya konursa `AttributeError` |
| `stream` | Bayraklar root callback'te | `agent-stream -n 3` alt komut yazmadan çalışsın; `stream` adı yine de açık dursun |
| `main` | `except BrokenPipeError` | `agent-stream \| head` boruyu kapatınca traceback basılmamalı |
| `Reader.poll` | `MARKS` ön elemesi | Tek `"tool_use"` testi notları kaçırıyordu; `<command-message>` de listede çünkü döngü ateşlemesinin `origin` alanı yok, başka hiçbir imzası da yok (11.09) |
| `Reader.poll` | `TAIL_BYTES` 1 MB + tek satırsa 8 katı | Ekran görüntüsü sonuçları transcript'e 850 KB'lık tek satır yazıyor; 256 KB'lık kuyruk o satırın içine düşünce `wait` oturumu hiç görmüyordu (11.09 e58f) |
| `Reader.poll` | tur sonunda zaman damgasıyla kararlı sıralama | Olaylar dosya sırasıyla geliyordu; iki oturum aynı saniyelerde yazınca akışta 05:30:42 satırı 05:30:40'tan önce düşüyordu (11.09 telefon). `end` için `ended`, `start` için `started`, not için `ts` |
| `Reader.poll` | `mid` → ilk satır atılır | Kuyruktan başlayınca ilk satır yarım JSON; `json.loads` zaten atar ama bir sonraki satır yanlış birleşmesin diye baştan kesilir |
| `Reader._side` | `if not first: return` (turn) | Aynı API yanıtı transcript'te birkaç `assistant` satırına bölünür, hepsi `end_turn` taşır; metinsiz olanlar basılsa "tur bitti" iki üç kez düşüyordu (11.09 d204'de görüldü) |
| `Reader._side` | `origin is None` + `<command-message>` → `fire` | `/loop` ve cron ateşlemeleri `origin` taşımıyor; insan satırı sayılsa watcher oturumu her 10 dakikada "seni bekliyor" diyordu |
| `Reader._events` | `ScheduleWakeup`/`CronCreate` → `loops` | Dinamik döngü ateşlemeyi kendisi planlar; `end_turn` sonrası uyanmayı bekler, kullanıcıyı değil |
| `Reader._events` | `Monitor` / `run_in_background` → `bg` sayacı | Arka plan işi varken `end_turn` kullanıcıyı değil bildirimi bekler; sayaç turlar boyu sürer, `task-notification` düşürür (11.09 ekran görüntüsü: "1 running task" varken "tur bitti" yazıyordu) |
| `unmark` | tur özetinde `**`, backtick, `#` ayıklanır | Ajanın ilk cümlesi markdown; akışta `**Hot fix indi:**` diye ham düşüyordu |
| `apply` | `turn`, `ask` varken ezmez | Soru sorulduktan sonra da `end_turn` gelir; soru daha somut bilgi, kaybolmamalı |
| `cmd_dash` | Bekleyen şerit `stale`'in 4 katı | Sonsuz tutmak kapanmış oturumu panoda bırakıyordu; hiç ayrıcalık vermemek 15 dakikalık soruyu düşürüyordu |
| `cmd_dash` | Açılışta `running` → `last` | Kuyruk tohumunda yarım kalan `tool_use` gerçekte bitmiş olabilir; spinner sonsuza dek dönerdi |
| `ctx_bar` | `CTX_WINDOW` tek sabit | Modele göre pencere tablosu tahmin olurdu; sayı ham gösterilir, çubuk `ctx_window` ayarıyla ölçeklenir |
| `WebSink.feed` | `export_html(clear=True)` + `StringIO` truncate | Kayıt konsolu hem segment listesini hem dosyayı biriktirir; ikisi de boşaltılmazsa bellek akışla büyür |
| `WebSink._emit` | `queue.Full` → istemci düşer | Telefonu uyuyan bir istemci kuyruğu doldurur; bloklamak ana akışı durdururdu |
| `WebSink._sse` | 15 sn `: ping` | Bazı proxy/tarayıcılar sessiz SSE'yi keser; `EventSource` yeniden bağlanır ama halkayı baştan alır |
| `web_theme` | özel `TerminalTheme` | Rich'in `MONOKAI` terminal teması `green`'i #527618 basıyor; şerit renkleri telefonda okunmuyordu |
| `lan_ip` | UDP `connect` numarası | Paket gitmez, yalnız çekirdeğin seçeceği kaynak adres okunur; `gethostbyname` çoğu Mac'te 127.0.0.1 döner |
| `announce` | QR `out=sys.stderr` | segno varsayılan stdout'a basar; stdout veri kanalı (2 numaralı kural) |
| `highlight` | `no_wrap=False, overflow="fold"` | `Syntax.highlight` no_wrap döner; uzun tek satır komut terminalde ve telefonda sağdan kesiliyordu (11.09 telefon ekran görüntüsü: `git add src/lib/` diye bitiyordu) |
| `Reader._summary` | anahtar sırası + `actions` adları | MCP çağrıları ham JSON olarak düşüyordu; `browser_batch` için adım adları, kalan için yalnız kısa skaler alanlar |
| `StreamView.note` | `width = max(..., 240)` + fold | `»` ve `■` satırları telefonda 42 karakterde kesiliyordu; sarılınca çubuk devam ediyor, okunur |
| `Cmd.body` | boş satır elenir | `-n 4` kuyruğunda iki boş satır iki gerçek satırı yiyordu |
| `cmd_wait` | `waiting_s` yalnız beklerken | `since` cevap sonrası da duruyor; "boşta" satırında süre yanıltıyordu |

## Bilinen Sınırlar

- Cloud oturumları görünmez: yerel transcript yazmıyorlar.
- Varsayılan tüm araçlar; `-B/--bash-only` yalnız kabuk komutlarını bırakır.
- Yoklama 250 ms (`--interval`); göz kararı anlık ama tam senkron değil.
- Transcript'ler varsayılan 30 gün tutulur; `replay` ve `stats` o pencereyle sınırlı.
- "Tur bitti" kapatılmış oturumda da görünür; transcript'te kapanış imzası yok.

## Doküman Bakımı

| Değişiklik | Güncellenecek | checks.sh yakalar mı |
| --- | --- | --- |
| Alt komut ekleme/çıkarma | README görünüm tablosu · bu dosyadaki görünüm tablosu | ✅ |
| Yeni bağımlılık | shebang'deki PEP 723 bloğu | ✅ |
| Çıkış kodu sözleşmesi | README · bu dosya | ✅ |
| Yeni tuzak/gerekçe | Kodda tek satır yorum + "Savunma Satırları" tablosu | ✅ 4+ satırlık blok reddedilir |

Yorum politikası: kodda bölüm başlıkları ve **tek satırlık** "ne yapıyor" notları kalır;
"neden" buraya yazılır. `checks.sh` bunu zorlar — 4 veya daha fazla ardışık yorum satırı
CI'yı kırar (dosya başlığındaki banner ve `# ───` bölüm başlıkları hariç).
