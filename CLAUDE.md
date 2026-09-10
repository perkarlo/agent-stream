# CLAUDE.md

Claude Code için proje rehberi. Kullanıcıya dönük anlatım README.md'de; burası kural,
sözleşme ve gerekçe kaydıdır.

## Proje

Claude Code oturumlarının çalıştırdığı komutları ve çıktılarını terminalde gösteren tek
dosyalık Python CLI. Kaynak, oturumların kendi yazdığı transcript'ler:
`~/.claude/projects/<proje>/<session>.jsonl`. Araç yalnız okur.

```
.
├── agent-stream                # tek çalıştırılabilir; tüm kod burada
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

## Python Standartları

Tek dosya, PEP 723 inline bağımlılık bloğu (`typer`, `rich`), shebang `uv run --script`.
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
| `agent-stream sessions` | `sessions` | Etiket, proje, boşta kalma, boyut |
| `agent-stream replay <etiket>` | `replay` | Takip etmez; komut ve çıktısını eşli basar |

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
| `Reader.files` | Stale filtresi yalnız **yeni** dosyaya | Takip edilen bir oturum sessizleşince akıştan düşmemeli |
| `cmd_block` / `lane_panel` | `theme=THEME`, varsayılan `ansi_dark` | ANSI teması rengi terminalin paletinden alır: aynı çıktı bir terminalde yeşil, başkasında mavi görünür. Sabit tema isteyen `--theme` ile pinler; varsayılanı değiştirmek herkesin terminal profilini ezmek olurdu |
| `pretty_tool` | `UUID` sunucu adı → `mcp:` | Konnektör MCP sunucuları 36 karakterlik uuid adı taşıyor; ham hâli komut satırının yarısını yiyordu |
| `clean` | `SYSREM` deseni | `tool_result` içine eklenen `<system-reminder>` blokları kullanıcının komut çıktısı değil |
| `parse_ts` | `.replace("Z", "+00:00").astimezone()` | Transcript UTC yazar; ekranda yerel saat okunur |
| `lane_panel` | Çıktı kuyruğu komutun hemen altında | Dibe yapıştırılınca (ilk tasarım) uzun terminalde komut ile çıktısı arasında ekran boyu boşluk kalıyordu; kuyruk yine son satırlar, ama başlığa bitişik |
| `lane_panel` | `Panel(..., width=width)` | Genişlik verilmezse `Columns` panelleri yan yana değil alt alta yığar |
| `lane_panel` | Spinner gövdede, özet altyazıda | `Panel(subtitle=…)` yalnız metin kabul eder; `Columns` altyazıya konursa `AttributeError` |
| `stream` | Bayraklar root callback'te | `agent-stream -n 3` alt komut yazmadan çalışsın; `stream` adı yine de açık dursun |
| `main` | `except BrokenPipeError` | `agent-stream \| head` boruyu kapatınca traceback basılmamalı |

## Bilinen Sınırlar

- Cloud oturumları görünmez: yerel transcript yazmıyorlar.
- Varsayılan tüm araçlar; `-B/--bash-only` yalnız kabuk komutlarını bırakır.
- Yoklama 250 ms (`--interval`); göz kararı anlık ama tam senkron değil.
- Transcript'ler varsayılan 30 gün tutulur; `replay` o pencereyle sınırlı.

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
