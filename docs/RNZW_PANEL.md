# Painel RNZW

Painel SwiftUI compacto, com largura máxima de 350 pontos, fundo grafite e cantos de 24 pontos. Os dois menus, **Opções** e **Créditos**, ficam no topo. O vermelho destaca a identidade e as opções ativas; os controles ativos têm fundo preto. A altura acompanha o conteúdo, sem ocupar a tela inteira.

## Ativar e restaurar

- **Primeiro toque na opção desligada:** aplica o pacote diretamente pelo motor 3105.
- **Novo toque na opção ativa:** restaura os arquivos originais usando o backup do motor.
- Durante a operação, a opção mostra progresso e os demais controles de escrita ficam bloqueados, evitando toques duplicados.
- O quadrado só fica marcado depois que o motor confirma a aplicação. Na restauração, só desmarca depois da confirmação. Se houver falha, o estado é relido dos registros do executor e o erro é exibido.
- Ao reabrir o painel, o estado é recuperado dos backups ativos, sem depender de uma preferência visual salva.

Não há seleção em lote, botão Executar nem botão separado de restauração. Feche o app de destino antes de tocar nas opções. Reset Guest altera os dados de convidado; para desfazer, toque novamente e aguarde a restauração do backup.

## Pacotes

| Opção | Arquivo original enviado |
| --- | --- |
| 144 FPS | `144 FPS.3105` |
| Aimhead Lock | `NO HEAD FFTH.3105` |
| Reset Guest | `RESETAR GUEST (2).3105` |

Os arquivos originais, com sua proteção original, ficam em `SourcePackages/`. A associação de NO HEAD FFTH a Aimhead Lock foi confirmada pelo solicitante.

Para permitir o toque direto sem pedir senha, `ThreeOneOSFive/Resources/PanelPackages/` contém cópias em modo público, suportado pelo codec original 3105. As cópias foram preparadas com as senhas fornecidas pelo solicitante, sem gravar essas senhas no código. Somente o envelope de proteção de 144 FPS e Reset Guest foi alterado: IDs, chaves de conteúdo, payloads criptografados e dados de substituição foram preservados. O Aimhead Lock já usava o modo público.

A validação mantém AES-GCM, fingerprints e digests. Os três pacotes fornecidos têm destinos de arquivo diferentes. O controlador também recusa uma nova ativação que sobrescreveria um arquivo de outra opção ativa, preservando a possibilidade de restauração.

## Executor de arquivos e créditos

O ícone de importação no cabeçalho abre o executor original, incluindo importação de outros `.3105`, edição, aplicação, exportação e restauração. Arquivos protegidos importados manualmente continuam usando o fluxo de senha original. Links de importação externos continuam funcionando e aguardam a operação atual terminar antes de abrir o executor.

O menu Créditos abre:

- Telegram: https://t.me/rnzwmodz
- Discord: https://discord.gg/a4QmpBuw33
- Tutorial: https://www.youtube.com/@rnzwstore

O diagnóstico fica no rodapé. Licença e créditos da base foram preservados.

## Verificação

`python3 dev-tests/run-toggle-tests.py` compila o código real de `PanelExecutorStore.swift` no contêiner oficial `swift:6.0.3-jammy`, substituindo Combine e as APIs de dispositivo por componentes de teste. Requer Docker. Sete cenários passaram: aplicação direta e toque repetido durante a operação; restauração dos bytes originais; falha na aplicação; falha na restauração e nova tentativa; três opções independentes e recuperação de estado ao reabrir; conflito de destino; recurso ausente.

Esses testes verificam a orquestração do controlador com um serviço de dispositivo simulado. Não executam o motor iOS, a observação do Combine, o SwiftUI nem os exploits. A sintaxe dos arquivos Swift alterados, as referências do projeto Xcode e a autenticação e integridade dos três pacotes também foram verificadas separadamente.

A imagem em `docs/images/rnzw-panel-preview.png` é uma referência visual em HTML, não uma captura do app iOS. A referência tem aproximadamente 350 × 344 pixels e foi verificada em larguras de tela de 320, 390 e 768 pixels.

## Compilar e testar no iPhone

Abra `ThreeOneOSFive.xcodeproj` no Xcode, selecione o target **3105** e configure a assinatura conforme o README da base. Não altere o bundle identifier, pois o fluxo original depende dele.

```sh
xcodebuild -project ThreeOneOSFive.xcodeproj -scheme 3105 \
  -configuration Debug -sdk iphoneos CODE_SIGNING_ALLOWED=NO build
```

No iPhone compatível, valide cada opção: primeiro toque aplica; segundo restaura os arquivos originais; reabrir mantém o estado real; uma falha não indica uma restauração inexistente. Confira também os menus, os três links e a importação manual.

O ambiente de edição é Linux. A compilação completa Release para arm64 foi concluída com sucesso pelo GitHub Actions em macOS/Xcode. O script confirmou o executável arm64, os três recursos .3105 e a integridade do IPA. A assinatura e o funcionamento no iPhone ainda não foram verificados. O motor original de execução, backups, validação, restauração e compatibilidade não foi alterado.


## Gerar IPA pelo GitHub Actions

O workflow **Build iOS IPA** compila o target 3105 em um runner macOS com Xcode, para arm64 e sem assinatura. Ele é acionado por alterações de código na branch `painel-rnzw` e também pode ser executado manualmente no menu Actions quando o workflow estiver disponível na branch padrão.

Abra a execução em https://github.com/rnzwconta9-a11y/xiter-gratis-psico/actions e, após concluir com sucesso, baixe o artefato **RNZW-unsigned-IPA**. O ZIP do artefato contém `RNZW-unsigned.ipa` e seu SHA-256. O artefato fica disponível por 14 dias e o download pelo GitHub pode exigir login. O log de compilação é salvo separadamente, inclusive em caso de falha.

Para compilar em um Mac local, rode `bash scripts/build-ipa.sh`. O script verifica a arquitetura arm64, a presença dos três pacotes e a estrutura do ZIP antes de concluir. Ele não altera o bundle identifier nem exige um certificado para a compilação.

O IPA gerado dessa forma não está assinado. Para instalar e utilizar as funções da base, ainda é necessária uma assinatura compatível com os requisitos originais do 3105. Certificados, perfis e senhas não fazem parte do repositório nem dos artefatos.

Compilação concluída: [execução #1](https://github.com/rnzwconta9-a11y/xiter-gratis-psico/actions/runs/39025295138). Artefato: **RNZW-unsigned-IPA** (aproximadamente 2,89 MB). Faça login no GitHub para baixar o ZIP do artefato e extrair o IPA.
