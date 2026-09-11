# agent-stream

Claude Code oturumlarının çalıştırdığı komutları ve çıktılarını terminalde canlı akıtır.
Kaynak, her oturumun kendi yazdığı transcript: `~/.claude/projects/<proje>/<session>.jsonl`.
Hook yok, sarmalayıcı yok, oturuma dokunmuyor: salt okunur bir takipçi.

```bash
astream                       # tüm aktif oturumların komut akışı
asdash                        # paralel oturumlar için canlı pano
astream wait                  # senden cevap bekleyen oturumlar
```

## Görünümler

| komut | ne yapar |
| --- | --- |
| `astream` | komut çalıştığı an başlığıyla düşer, çıktısı bitince altına eklenir |
| `astream --pair` | komutu çıktısıyla birlikte, bittiğinde tek blok halinde yazar |
| `astream dash` | oturumları yan yana şeritlerde gösterir; çalışan komutta spinner, altta son 5 komut. Komut ilk 4 satırıyla durur (`-m`) |
| `astream wait` | senden cevap bekleyen oturumlar: açık soru, seçenekleri, tur sonu, bekleme süresi, bağlam, model. `--all` çalışan ve döngüdekileri de gösterir |
| `astream sessions` | aktif oturumlar: etiket, proje, boşta kalma süresi |
| `astream replay a3d1` | geçmiş bir oturumun tüm komutlarını baştan yazar |
| `astream stats` | son 7 günün özeti: oturum, istek, soru, komut, hata, araç ve model dağılımı, saat histogramı, gece payı. `--since 24h` |

## Oturumlar sana gelir

Akış yalnız komutları değil, oturumun senden ne beklediğini de yazar. Komut dışı olaylar
tek satırdır, işareti şerit çubuğuna biner:

| işaret | olay | kaynak |
| --- | --- | --- |
| `»` | senin yazdığın istek | `origin.kind == human` |
| `?` | soru soruldu, seni bekliyor; altında seçenekler | `AskUserQuestion` / `ExitPlanMode` çağrısı açık |
| `↩` | soruya verdiğin cevap | aynı çağrının sonucu |
| `■` | tur bitti, seni bekliyor; yanında son cümle | `stop_reason: end_turn` |
| `⟳` | döngü uyandı (`/loop`, cron); tur sonu seni beklemez | `origin`'siz slash komutu ya da `ScheduleWakeup` |
| `⟲` | bağlam özetlendi | compaction |
| `⚠` | api hatası | `system/api_error` |

Panoda soru bekleyen şerit sarı kenarlıkla öne geçer, başlığında `? Şema seçimi` yazar;
tur bitmiş şerit `■` alır ve onu izler. Altyazıda bağlam çubuğu `▮▮▮▮▯ 674k` (tavan 1M,
`ctx_window` ile değişir; %60 sarı, %80 kırmızı) ve bekleme süresi `⧗ 3dk` durur.
Pano açılışta her dosyanın son 256 KB'ından durumu kurar; akış açılışta yine sondan başlar.

`--bell` soru ve tur sonunda terminal zili çalar (döngü uyanışları hariç); `--no-notes` bu
satırların hepsini kapatır. `-q` çıktıyı gizler ama patlayan komutun ilk 3 satırı yine düşer.

Her oturumun 4 karakterlik bir etiketi (`a3d1`) ve id'sinden türeyen sabit bir rengi var;
şerit çubuğu `▌` o renkte. Subagent'lar kendi etiketini, rengini ve panoda kendi şeridini alır,
başlıkta `⤷ Explore` gibi tipiyle görünür (`--no-subagents` gizler).

Araç işaretleri: `$` Bash · `▸` Read · `✎` Edit/Write · `⌕` Grep/Glob/WebSearch · `⇣` WebFetch ·
`⤷` Task · `◇` Skill · `⚙` MCP (`mcp__trello__trello_list_cards` → `trello:list_cards`).

## Sık kullanılan bayraklar

```bash
astream -p myapp -n 6          # sadece myapp projesi, komut başına 6 satır çıktı
astream -s a3d1                # tek oturum
astream -q                     # sadece komutlar, çıktı yok (hatada 3 satır)
astream -q --bell              # soru ya da tur sonunda zil
astream --errors               # yalnız hata veren komutlar, eşli
astream --no-notes             # insan satırı, soru, tur sonu gizli
astream -m 4                   # uzun heredoc komutlarını 4 satırda kır (varsayılan 6, 0 = sınırsız)
astream -B                     # yalnız Bash (varsayılan: Read, Edit, Grep, Task, MCP dahil hepsi)
astream --theme ansi_dark      # komut bloğu teması (varsayılan monokai): nord, dracula, ansi_dark…
astream -b 20                  # açılışta son 20 komutu da göster
astream --json | jq -r '.command // empty'   # NDJSON; `event` alanı command · human · ask · answer · turn · fire · compact · apierr
```

`--no-color`, `NO_COLOR`, `TERM=dumb` ve boru hattı algısı destekleniyor.

| Çıkış kodu | Anlam |
| --- | --- |
| `0` | Normal çıkış |
| `1` | Hata (kök dizin yok, oturum bulunamadı) |
| `2` | Kullanım hatası (bilinmeyen bayrak, panoyu boru hattında açmak) |
| `130` | `Ctrl+C` |

## Ayar

Öncelik: bayrak > ortam değişkeni > ayar dosyası > varsayılan.

- Ortam: `AGENT_STREAM_PROJECT`, `AGENT_STREAM_ROOT`
- Dosya: `~/.config/agent-stream/config.toml`

```toml
[genel]
project = "myapp"
max_lines = 8
stale = 45
theme = "monokai"
bell = true
ctx_window = 1000000
```

Varsayılan tema `monokai`: her terminalde aynı çıkar, 24 bit renk desteklemeyen terminallerde
en yakın renge yuvarlanır. `ansi_dark` renkleri terminalin kendi paletinden alır; tek renkli bir
profilde (yeşil üstü siyah gibi) sözdizimi boyaması bilgi taşımaz, o yüzden varsayılan değil.

Ayar dosyası `[genel]` bölümünün yanında alt komut bölümü de kabul eder (`[stream]`, `[dash]`,
`[wait]`, `[sessions]`, `[replay]`, `[stats]`); alt komut bölümü `[genel]`i ezer, bayrak ve ortam değişkeni ikisini de.

## Kaynak tüketimi

Araç olay tabanlı çalışır: dosyalar yazıldığında çekirdek uyandırır, kimse yoklamaz.

| | boşta | komut akarken |
| --- | --- | --- |
| akış · kqueue (macOS) | %0,04 CPU | + komut başına 1,5 ms |
| akış · inotify (Linux) | aynı sınıf | + komut başına 1,5 ms |
| akış · yoklama fallback | %0,22 CPU | + komut başına 1,5 ms |
| pano | %0,44 CPU | %1,9 CPU (4 fps) |

Karşılaştırma için 1.0.0 sürümü boşta %1,45, pano açıkken %8,8 harcıyordu. Bellek 11-31 MB,
açılış ~120 ms. Ölçümü kendin tekrarlamak için:

```bash
./bench/bench.py
```

Arka uç `AGENT_STREAM_WATCH` ile zorlanabilir: `auto` (varsayılan) · `kqueue` · `inotify` · `poll`.
Kurulamayan arka uç sessizce yoklamaya düşer, davranış değişmez.

## Sınırlar

- Cloud oturumları görünmez; yerel transcript yazmıyorlar.
- Varsayılan tüm araçlar; `-B/--bash-only` akışı yalnız kabuk komutlarına indirir.
- Yoklama 250 ms; göz kararı anlık ama tam senkron değil.
- Transcript'ler varsayılan olarak 30 gün tutuluyor, `replay` ve `stats` o pencereyle sınırlı.
- Bekleme sinyali transcript'ten türer: `end_turn` sonrası oturum kapatılmışsa da "tur bitti" görünür; pano bekleyen şeridi `stale`'in dört katı tutar, sonra düşürür.
- Bağlam çubuğunun tavanı tek sayı (`ctx_window`); modele göre pencere farkı bilinmiyor, sayı her zaman ham token.

## Çalıştırma ve depo

Dosyanın shebang'i `uv run --script`; bağımlılıklar (typer, rich) ilk çalıştırmada
uv tarafından kurulur, sonra ~0.3 sn'de açılır. uv yoksa `python3 agent-stream` da çalışır.

`.zshrc` içindeki alias'lar: `astream` (akış) ve `asdash` (pano).

```
agent-stream            tek çalıştırılabilir, tüm kod burada
README.md               bu dosya
CLAUDE.md               Claude Code için kural ve gerekçe kaydı
config.example.toml     ayar dosyası örneği
.github/checks.sh       kod ↔ doküman tutarlılık kontrolleri
```

Değişiklikten sonra: `./.github/checks.sh`
