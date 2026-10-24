# Auditoria de código — 23/10/2026

## Resultado

A pasta `Tests` foi removida depois da execução das verificações. Foram retirados seus 115 arquivos (39 scripts, 36 cenas, 39 arquivos de UID e um documento), além de três relatórios antigos de testes na raiz. Não há referência de execução a `res://Tests/` nas configurações, cenas, recursos ou scripts restantes.

A validação final carregou **377 arquivos: 236 scripts e 141 cenas/recursos**, sem falhas de carregamento, mensagens de erro de script ou erros de Unicode. A inicialização pelo menu principal também terminou sem mensagens de erro. O Godot utilizado foi 4.7.2.

## Correções feitas

- `Tutorial/tutorial.gd`: removida a indentação antes de `extends`, que impedia a compilação do tutorial separado.
- `Scenes/andar_data_center.tscn`: salva a conexão do sinal `solicitou_inicio` do caminho `CaminhoAtePaineis` com o cientista. O outro caminho já tinha essa conexão.
- Minigame de eletrônica e controlador do final do engenheiro: o reinício interno do circuito agora informa a nova instância ao controlador. Assim, pausar, retomar e sair continuam usando o circuito atual depois de queimar a bateria antes da hora. O teste verificou explicitamente a pausa e a retomada após a substituição.
- Idiomas: substituídos os nomes de idioma usados como locale pelos códigos `pt_BR`, `en`, `es` e `fr`. Os nomes exibidos e os valores existentes nas configurações salvas foram mantidos. As quatro traduções foram regeneradas e os recursos anteriores substituídos.
- Seleção de idioma: corrigida a comparação incorreta com `PORTUGUÊSE`.

## Verificações executadas

Antes da exclusão dos testes, foram exercitados os 39 cenários existentes. A análise cobriu movimento, empurrar em quatro direções, atraso do empurrão automático, colisões e deslocamento dos NPCs, chegada ao elevador, organização das tarefas, orientação de objetivos, coleta e troca automática de itens, falta de extintores e reinício, tutoriais, controles e remapeamento, acessibilidade, diálogos e interrupções, RFID, queda e retorno da energia, alarme, áudio ambiente, drones e combate, refrigeração, geração dos canos e minigames finais.

As verificações funcionais foram concluídas após distinguir falhas reais de testes desatualizados. Somente na cópia temporária, os testes antigos foram adaptados para os nomes atuais das APIs (`id_item` e `_ja_visto`), para o reinício interno dos circuitos, para a presença dos itens iniciais no inventário e para a abertura real dos menus. Na refrigeração, o temporizador foi congelado para conferir o bônus sem depender da duração de carregamento da máquina. Essas adaptações não foram incorporadas ao jogo.

Os seis objetivos eletrônicos e a repetição da tentativa após a bateria queimar antecipadamente passaram. Os filtros foram verificados com renderização real. O áudio dos seis cenários foi verificado com dispositivo de áudio real, pois o modo headless não produz amostras de saída para essa medição. As traduções de “Novo Jogo” e os códigos de locale foram conferidos nos quatro idiomas, sem erros de Unicode.

As execuções ocorreram numa cópia temporária com diretório próprio de dados de usuário, sem utilizar os arquivos de progresso do jogador.

## Limites e avisos observados

Alguns testes encerrados enquanto havia efeitos ou corrotinas em andamento emitiram avisos de objetos e recursos ainda pendentes no encerramento. Eles estão separados das falhas funcionais e não foram ocultados nem tratados como prova de ausência de vazamentos. Também apareceu em alguns testes o aviso nativo de ajuste da Camera2D ao processamento físico por causa da interpolação. A compilação integral e a inicialização final não apresentaram esses avisos.

A auditoria verifica compilação, dependências, inicialização e os cenários automatizados disponíveis. Ela não equivale a percorrer manualmente todas as combinações possíveis de entrada, checkpoint e decisões de uma partida completa, nem a certificar ausência absoluta de bugs.

Nenhum commit foi criado nesta tarefa. Os testes originais e os registros de execução foram preservados fora do projeto em uma cópia temporária; eles não fazem parte da entrega versionada.