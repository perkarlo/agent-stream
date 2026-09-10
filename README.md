# agent-stream

Claude Code oturumlarının çalıştırdığı komutları ve çıktılarını terminalde canlı akıtır.
Kaynak, her oturumun kendi yazdığı transcript: `~/.claude/projects/<proje>/<session>.jsonl`.
Hook yok, sarmalayıcı yok, oturuma dokunmuyor: salt okunur bir takipçi.

```bash
astream                       # tüm aktif oturumların komut akışı
asdash                        # paralel oturumlar için canlı pano
```

## Görünümler

| komut | ne yapar |
| --- | --- |
| `astream` | komut çalıştığı an başlığıyla düşer, çıktısı bitince altına eklenir |
| `astream --pair` | komutu çıktısıyla birlikte, bittiğinde tek blok halinde yazar |
| `astream dash` | oturumları yan yana şeritlerde gösterir; çalışan komutta spinner, altta son 5 komut |
| `astream sessions` | aktif oturumlar: etiket, proje, boşta kalma süresi |
| `astream replay a3d1` | geçmiş bir oturumun tüm komutlarını baştan yazar |

Her oturumun 4 karakterlik bir etiketi (`a3d1`) ve id'sinden türeyen sabit bir rengi var;
şerit çubuğu `▌` o renkte. Subagent'lar `⤷ subagent` ile işaretlenir.

## Sık kullanılan bayraklar

```bash
astream -p myapp -n 6          # sadece myapp projesi, komut başına 6 satır çıktı
astream -s a3d1                # tek oturum
astream -q                     # sadece komutlar, çıktı yok
astream -m 4                   # uzun heredoc komutlarını 4 satırda kır (0 = sınırsız)
astream -a                     # Bash dışındaki araçlar da (Read, Edit, Grep, Task…)
astream -b 20                  # açılışta son 20 komutu da göster
astream --json | jq -r .command   # NDJSON, satır başına bir tamamlanmış komut
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
```

## Sınırlar

- Cloud oturumları görünmez; yerel transcript yazmıyorlar.
- MCP araç çağrıları `Bash` değil, `-a` ile gelirler.
- Yoklama 250 ms; göz kararı anlık ama tam senkron değil.
- Transcript'ler varsayılan olarak 30 gün tutuluyor, `replay` o pencereyle sınırlı.

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
