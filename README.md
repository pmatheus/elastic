# Configuração do Projeto Elastic

Este utiliza docker para criar o Elastic Stack (Elasticsearch, Kibana, Fleet).

## Pré-requisitos

- Docker e Docker Compose instalados.

## Como Executar

1.  **Configurar Variáveis de Ambiente:**
    *   Copie o arquivo `env.example` para um novo arquivo chamado `.env`.
        ```bash
        cp env.example .env
        ```
    *   Edite o arquivo `.env` com as configurações desejadas. Preste atenção especial às seguintes variáveis:
        *   `ELASTIC_PASSWORD`: Senha para o usuário `elastic`.
        *   `KIBANA_PASSWORD`: Senha para o usuário `kibana_system` (usado pelo Kibana para se conectar ao Elasticsearch).
        *   `FLEET_SERVER_HOST`: O endereço IP ou nome de host da máquina onde o Fleet Server estará acessível (geralmente o IP da máquina host do Docker).
        *   Outras variáveis conforme necessário para sua configuração.

2.  **Iniciar os Serviços com Docker Compose:**
    *   No diretório raiz do projeto (onde o arquivo `docker-compose.yml` está localizado), execute o seguinte comando para iniciar todos os serviços em segundo plano:
        ```bash
        docker-compose up -d
        ```
    *   **Outros comandos úteis do Docker Compose:**
        *   Para verificar o status dos contêineres em execução:
            ```bash
            docker-compose ps
            ```
        *   Para visualizar os logs de um serviço específico (substitua `<nome_do_serviço>` pelo nome do serviço, ex: `elasticsearch`, `kibana`):
            ```bash
            docker-compose logs -f <nome_do_serviço>
            ```
        *   Para reiniciar um serviço específico:
            ```bash
            docker-compose restart <nome_do_serviço>
            ```
        *   Para parar todos os serviços:
            ```bash
            docker-compose down
            ```
        *   Para parar e remover os volumes (ATENÇÃO: isso removerá os dados persistidos):
            ```bash
            docker-compose down -v
            ```
        *   Para baixar as versões mais recentes das imagens definidas no `docker-compose.yml` (útil antes de um `up`):
            ```bash
            docker-compose pull
            ```

3.  **Acessar os Serviços:**
    *   Kibana: `http://localhost:5601` (ou o IP da sua máquina host do Docker se não estiver acessando localmente).
    *   Elasticsearch: `https://localhost:9200` (ou o IP da sua máquina host do Docker).

## Configurações Manuais Necessárias no Fleet

Após a instalação e configuração inicial, algumas configurações manuais são necessárias diretamente na interface do Fleet para garantir a correta comunicação com o Elasticsearch, especialmente se estiver utilizando certificados autoassinados.

Siga os passos abaixo:

1.  Acesse a interface do Kibana.
2.  Navegue até **Management > Fleet**.
3.  Em **Settings** (Configurações), na seção **Outputs**, clique no ícone de lápis (editar) para modificar a configuração de saída.
4.  **Alterar o Host do Elasticsearch:**
    *   Localize o campo referente aos `hosts` do Elasticsearch.
    *   Altere o valor para o endereço IP correto do host onde o Elasticsearch está sendo executado. Por exemplo: `https://SEU_IP_DO_ELASTICSEARCH:9200`.
5.  **Configurar Verificação SSL (para certificados autoassinados):**
    *   Se você estiver utilizando certificados SSL autoassinados para o Elasticsearch, é necessário desabilitar a verificação estrita do certificado pelo Fleet Agent.
    *   Adicione a seguinte configuração na seção de saída (output configuration YAML):

        ```yaml
        ssl.verification_mode: none
        ```

    *   Isso instrui o Fleet Agent a não verificar a validade do certificado SSL, o que é comum em ambientes de desenvolvimento ou teste com certificados autoassinados.

6.  Salve as alterações.

Após essas configurações, os Fleet Agents deverão conseguir se comunicar corretamente com o seu cluster Elasticsearch.
