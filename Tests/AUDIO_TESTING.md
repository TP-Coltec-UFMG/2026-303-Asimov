# Verificação de áudio

Os testes são cenas/scripts executados pelo próprio Godot. As cenas de teste
usam a sessão temporária do modo dev para não gravar a campanha nem as preferências.

- `movement_audio_test.tscn -- --movement-audio-test`: 27 verificações usando
  o Player real, entrada de movimento e colisões. Cobre passos originais,
  parede, arrastar, soltar, bloqueio de física, visibilidade, pausa e troca de cena.
- `ambient_audio_test.tscn -- --ambient-audio-test`: música global sem
  atenuação por câmera, pausa nativa e explícita, batimento/estamina,
  transições das músicas 2 → 3 → 5 e referências liberadas.
- `--script Tests/interaction_audio_test.gd`: repetição de interação,
  sequência RFID sem sobreposição, limite de vozes, pausa e descarte ao sair.
- `scene_audio_test.tscn -- --scene-audio-test`: carrega os seis cenários reais,
  mede amostras da saída do mixer, verifica emendas da ventilação e pausa,
  e dispara os eventos de goteira e metal no hall.

Exemplo: `godot --path . --headless Tests/movement_audio_test.tscn -- --movement-audio-test`.
Para inspecionar visualmente os cenários e testar o dispositivo de áudio,
execute o teste de cenas sem `--headless`.

Validação em 25/09/2026: quatro testes aprovados em Godot 4.7.2. O teste de
cenários também foi executado com janela e driver de áudio do Windows.
Nas janelas de captura de 0,5 segundo, os picos ficaram entre -28 e -16,8 dB,
sem saturação. Isso verifica a saída digital e o ciclo de reprodução;
a preferência de timbre/volume continua sendo uma avaliação auditiva do jogador.

Fontes dos arquivos externos: `Sounds/External/SOURCES.md`.
