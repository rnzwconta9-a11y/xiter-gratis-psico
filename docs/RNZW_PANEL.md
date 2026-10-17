# Painel RNZW

Interface nativa em SwiftUI, com fundo branco, seleção preta e vermelho reservado à identidade e à ação principal. Os dois menus são **Opções** e **Créditos**.

## Pacotes incluídos

| Opção | Arquivo enviado | Proteção |
| --- | --- | --- |
| 144 FPS | `144 FPS.3105` | Senha original, solicitada no app |
| Aimhead Lock | `NO HEAD FFTH.3105` | Sem senha |
| Reset Guest | `RESETAR GUEST (2).3105` | Senha original, solicitada no app |

Os três arquivos foram copiados sem alterar seu conteúdo para `ThreeOneOSFive/Resources/PanelPackages`. O projeto Xcode inclui essa pasta como recurso. A associação de NO HEAD FFTH a Aimhead Lock foi confirmada pelo solicitante; o nome na interface não muda o conteúdo do pacote.

## Uso

1. Marque os quadrados das opções desejadas; eles ficam pretos. Marcar e desmarcar apenas muda a seleção.
2. Feche o app de destino e toque em **Executar selecionadas**. Confirme a operação. Reset Guest tem uma mensagem específica sobre os dados de convidado.
3. Informe, no próprio app, a senha original de cada pacote protegido. Todas as senhas e os pacotes são verificados antes de começar a aplicação. Cancelar essa preparação não aplica nenhum pacote.
4. O executor aplica os pacotes em sequência e informa o resultado. Um erro interrompe as opções restantes; opções já concluídas são identificadas na mensagem.
5. Para desfazer, selecione os pacotes aplicados e use **Restaurar selecionadas**. A restauração usa os backups e as verificações originais do 3105. Desmarcar uma opção não restaura arquivos.

A mesma opção não é reaplicada enquanto houver um backup ativo, para preservar os originais. Pacotes que alteram o mesmo arquivo são recusados em uma única execução; aplique e restaure cada um separadamente.

O botão de importação no canto superior direito abre o executor original, incluindo importação de outros `.3105`, edição, aplicação, exportação e restauração. Links de importação externos continuam sendo encaminhados a ele. O diagnóstico continua acessível no rodapé.

## Créditos

- Telegram: https://t.me/rnzwmodz
- Discord: https://discord.gg/a4QmpBuw33
- Tutorial: https://www.youtube.com/@rnzwstore

Os botões abrem esses endereços pelo sistema. O motor 3105, seus créditos, sua licença e os avisos de terceiros foram preservados.

## Compilar e validar no Mac

Abra `ThreeOneOSFive.xcodeproj` no Xcode. Selecione o target **3105** e configure a assinatura conforme o README da base. Não altere o bundle identifier: o fluxo de acesso original depende dele.

Para verificar a compilação para um dispositivo sem gerar assinatura:

```sh
cd /caminho/para/xiter-gratis-psico
xcodebuild -project ThreeOneOSFive.xcodeproj -scheme 3105 \
  -configuration Debug -sdk iphoneos CODE_SIGNING_ALLOWED=NO build
```

Esse comando verifica a compilação; uma instalação utilizável ainda exige a assinatura e um dispositivo compatível com a base. Não há certificados nem IPA assinado nesta source.

No iPhone, confira: alternância dos dois menus; quadrados pretos na seleção; abertura dos três links; importação de `.3105`; senha incorreta e cancelamento sem execução; execução com senha válida; tratamento de app ausente; restauração pelos backups. Valide cada pacote isoladamente antes de combinar opções.

## Limites da verificação no ambiente de edição

O ambiente disponível é Linux e não contém Xcode, SDK do iOS nem simulador. A validação aqui cobre a sintaxe com parser Swift, a estrutura do projeto e a integridade dos recursos. A compilação nativa, a assinatura, o acesso ao dispositivo e os efeitos dos pacotes no app de destino precisam ser verificados no Mac/iPhone.

Reset Guest e 144 FPS foram desbloqueados para validação com as respectivas senhas fornecidas pelo solicitante; a autenticação AES-GCM e os digests dos arquivos passaram nos dois casos. Nenhuma senha foi embutida na source. O app solicita as senhas originais na primeira execução e utiliza o Chaves do iOS para guardar as chaves de conteúdo, conforme o mecanismo original. Aimhead Lock também passou pela autenticação e verificação dos digests, usando a chave pública do próprio pacote.

O código de execução, criptografia, validação de caminhos, backups, restauração e compatibilidade da base não foi modificado. `PanelExecutorStore.swift` apenas conecta a interface a essas APIs existentes.
