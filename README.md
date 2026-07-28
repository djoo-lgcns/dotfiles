# LRM workflow handover overview

이 문서는 `lrm_service3`와 `lrm_service6` 인수인계 문서의 공통 개요다. 서비스별 상세는 아래 문서를 기준으로 읽는다.

- [lrm_service3_handover.md](lrm_service3_handover.md): 유사사례 검색 workflow
- [lrm_service6_handover.md](lrm_service6_handover.md): Contract VRB 작성 workflow

## 1. 전체 workflow의 목적

LRM 초안 작성 흐름에서 두 서비스는 서로 다른 문제를 해결한다.

```mermaid
flowchart TB
  FE["FE / LRM screens"] --> S3["lrm_service3<br/>유사 프로젝트와 리스크 검토 사례 검색"]
  FE --> S6["lrm_service6<br/>최종 계약서 기반 Contract VRB 검토의견 생성"]

  S3 --> PIDX[("OpenSearch<br/>lrm_review_project")]
  S3 --> RIDX[("OpenSearch<br/>lrm_review_risk_opinion")]
  S3 --> S3OUT["FE structured metadata<br/>SimilarCaseStructuredView"]

  S6 --> PDB[("PostgreSQL<br/>project_document / standard / standard_item")]
  S6 --> S3JSON[("S3<br/>converted contract JSON")]
  S6 --> LLM["Bedrock LLM<br/>chunk matching / synthesis"]
  S6 --> DR[("draft_result<br/>CONTRACT_VRB")]
```

`lrm_service3`는 프로젝트명을 기준으로 유사 프로젝트와 기존 법무 리스크 검토 내용을 찾아 FE가 구조화 카드로 표시할 metadata를 만든다. 최종 산출물은 markdown 본문보다 `metadata.projects` 구조가 중요하다.

`lrm_service6`는 프로젝트의 최종 계약서 변환 JSON을 읽고, Contract VRB 체크리스트 기반 탐지와 LLM 단독 plain 탐지를 병렬 수행한 뒤 줄글형 `## III. 검토의견`을 생성해 `draft_result`에 저장한다.

## 2. node 단위 data transition 해석 기준

두 workflow는 node 경계를 기준으로 실행 전 data, node 내부 전환, 실행 후 data contract를 분리해서 이해하면 된다.

```mermaid
flowchart LR
  A["Before node<br/>payload / context / config"] --> B["Node transition<br/>validate / normalize / search / merge / render"]
  B --> C["After node<br/>next payload"]
  B -. context write .-> D[("workflow context")]
  C --> G["Now we can guarantee<br/>다음 node가 의존할 수 있는 contract"]
  D --> G
```

node 종료 시점에 보장 가능한 범위는 node 종류별로 다르다.

| node 종류 | 보장 가능한 것 | 보장하지 않는 것 |
| --- | --- | --- |
| Logic Builder | schema를 통과한 payload shape, context write 위치, branch 조건 | 외부 DB/S3/LLM의 의미적 정답성 |
| Retriever | retriever output envelope와 `documents[]` shape | 검색 결과가 업무적으로 충분하다는 판단 |
| Flow selector | 다음 node id 선택 결과 | 선택된 branch가 business optimal이라는 판단 |
| LLM node | prompt executor가 반환한 raw response envelope | LLM response의 사실성, 완전성 |
| LLM 후처리 Logic Builder | parse/normalize/dedupe 이후 canonical shape | 누락된 리스크가 없다는 보장 |
| Final renderer | FE/DB가 소비하는 final response contract | 생성 문장의 법률적 완결성 |

따라서 `Now we can guarantee`는 “이제 다음 node가 어떤 data contract를 믿고 진행할 수 있는가”를 뜻한다.

## 3. 공통 data lane

workflow를 이해할 때는 data를 세 lane으로 분리한다.

```mermaid
flowchart TB
  subgraph Payload["payload lane"]
    P1["node output"]
    P2["next node input"]
    P1 --> P2
  end

  subgraph Context["context lane"]
    C1[("workflow context")]
    C2["ContextRead"]
    C3["ContextWrite"]
    C1 --> C2
    C3 --> C1
  end

  subgraph Final["final lane"]
    F1["metadata"]
    F2["draft_result"]
    F3["FE render model"]
  end

  P2 --> F1
  P2 --> F2
  F1 --> F3
```

`payload`는 바로 다음 node로 전달되는 값이다. `context`는 workflow 전체에서 재사용할 수 있도록 저장되는 값이다. `metadata/final`은 FE 또는 draft 저장 정책이 소비하는 값이다.

## 4. Logic Builder agent

기존 코드베이스에는 Logic Builder 관련 문서가 이미 분산되어 있다.

| 위치 | 핵심 내용 |
| --- | --- |
| `docs/development/servicew/implement-service-workflow-using-logic-builder-util-agent.md` | Logic Builder util agent로 service workflow를 구현하는 표준 가이드. `logic_key`, `logic_parameters`, `ServiceLogicContract`, schema/logic 파일 배치, FE schema API까지 설명한다. |
| `docs/development/agent/types/util-agents.md` | `util_agent_logic_builder`를 util agent 타입으로 소개한다. Agent Setting dropdown과 data flow가 Service Logic contract에서 파생된다는 점을 설명한다. |
| `aidlc-docs/inception/reverse-engineering/irax-agent-lrm-reverse-engineering/phase2-new-agent-implementation-guide.md` | 새 LRM node를 native agent로 만들지, Logic Builder logic으로 만들지 선택하는 기준을 제시한다. |
| `aidlc-docs/inception/reverse-engineering/irax-agent-lrm-reverse-engineering/code-structure.md` | DB DAG가 `logic_key`로 Python logic을 참조하고, `service_logic_bootstrap`이 registry를 구성한다는 reverse engineering 관점을 제공한다. |

`util_agent_logic_builder`는 node별 native agent class를 계속 늘리지 않기 위한 generic native agent다. DB에는 하나의 agent subtype으로 등록되어 있고, agent instance의 `custom_parameters.logic_key`가 실제 실행할 Python service logic을 결정한다.

Logic Builder 자체의 책임은 logic 선택, typed input 구성, context read/write rule 노출, output payload 변환이다. 실제 업무 동작은 선택된 service logic executor가 수행한다. LRM에서는 대부분 deterministic glue logic이지만, logic에 따라 DB/S3/embedding service처럼 외부 adapter를 호출하기도 한다.

### 4.1 Bird-eye view: DB node에서 Python logic까지

```mermaid
flowchart TB
  subgraph Seed["DB seed / migration"]
    SVC["irax.service<br/>lrm_service3 / lrm_service6"]
    DAG["irax.service_workflow<br/>node_id, next_node_ids"]
    INST["irax.agent_instance<br/>common_parameters<br/>custom_parameters.logic_key<br/>custom_parameters.logic_parameters"]
    AG["irax.agent<br/>agent_sub_type=util_agent_logic_builder"]
    SVC --> DAG --> INST --> AG
  end

  subgraph Builder["FE Agent Builder schema lane"]
    CAT["GET /logic/catalog<br/>logic dropdown"]
    SCH["GET /logic/schema?logic_key=...<br/>config/input/output/data-flow schema"]
    UI["Agent Setting UI<br/>logic_key immutable<br/>logic_parameters schema-driven accordion"]
    CAT --> UI
    SCH --> UI
  end

  subgraph Runtime["agent runtime lane"]
    LB["UtilAgentLogicBuilder<br/>NativeAgentBase"]
    BOOT["service_logic_bootstrap<br/>import */services/*/logics/*.py"]
    REG["ServiceLogicRegistry<br/>logic_key -> ServiceLogicSpec"]
    RUNNER["ServiceLogicRunner<br/>hydrate input -> execute -> NodeExecutionResult"]
    LB --> BOOT --> REG --> RUNNER
  end

  subgraph Code["service logic code bundle"]
    COMMON["schemas/common.py<br/>shared typed models / normalizers"]
    SCHEMA["schemas/&lt;logic&gt;.py<br/>Parameters / Input / Output / Contract"]
    LOGIC["logics/&lt;logic&gt;.py<br/>@register_service_logic executor"]
    HELPER["logics/*utils*.py<br/>pure helper functions"]
    COMMON --> SCHEMA
    SCHEMA --> LOGIC
    HELPER --> LOGIC
  end

  INST -->|logic_key| LB
  REG --> CAT
  REG --> SCH
  BOOT -->|module import triggers decorator| LOGIC
  SCHEMA -->|ServiceLogicContract auto registry| REG
  LOGIC -->|ServiceLogicSpec.executor| REG
  RUNNER -->|calls executor| LOGIC

  classDef db fill:#fff4ce,stroke:#ad8b00,color:#2f2100
  classDef ui fill:#e8f3ff,stroke:#2b6cb0,color:#102a43
  classDef run fill:#e8fff3,stroke:#2f855a,color:#102a43
  classDef code fill:#f3e8ff,stroke:#805ad5,color:#20123a
  class SVC,DAG,INST,AG db
  class CAT,SCH,UI ui
  class LB,BOOT,REG,RUNNER run
  class COMMON,SCHEMA,LOGIC,HELPER code
```

Now we can guarantee: DB seed에는 Python import path가 저장되지 않는다. 운영 중인 node가 어떤 코드를 실행할지는 `agent_instance.custom_parameters.logic_key`와 runtime registry의 `logic_key -> ServiceLogicSpec` 매핑만으로 결정된다.

### 4.2 `logic_key` resolution

실행 시점의 resolution은 아래 순서로 진행된다.

```mermaid
flowchart LR
  subgraph Before["Before node"]
    NI["NodeExecutionInput"]
    CFG["config.custom_parameters<br/>logic_key + logic_parameters"]
    PREV["prev_result<br/>parent node payload"]
    VIEW["context_view<br/>injections + workflow"]
    NI --> CFG
    NI --> PREV
    NI --> VIEW
  end

  subgraph Resolve["Resolve selected logic"]
    VALID["validate<br/>UtilAgentLogicBuilderCustomParameters"]
    BOOT["ensure_service_logic_registry_bootstrapped()"]
    SPEC["resolve_service_logic(logic_key)<br/>ServiceLogicSpec"]
    VALID --> BOOT --> SPEC
  end

  subgraph Hydrate["Hydrate typed input"]
    ENV["logic_payload envelope<br/>common/custom/context/prev"]
    CR["ConfigRead<br/>logic_parameters -> custom -> common"]
    XR["ContextRead<br/>context_parameters path lookup"]
    PR["PrevNodeOutput<br/>prev_result whole or path"]
    TIN["schema.Input<br/>Pydantic validated"]
    ENV --> CR --> TIN
    ENV --> XR --> TIN
    ENV --> PR --> TIN
  end

  subgraph After["After node"]
    EXEC["spec.executor(input, runtime)"]
    OUT["schema.Output or NodeExecutionResult"]
    NEXT["next payload"]
    CTX[("context_updates")]
    EXEC --> OUT
    OUT --> NEXT
    OUT -. ContextWrite .-> CTX
  end

  CFG --> VALID
  PREV --> ENV
  VIEW --> ENV
  SPEC --> ENV
  SPEC --> EXEC
  TIN --> EXEC
```

Resolution을 코드 기준으로 풀면 다음과 같다.

1. `UtilAgentLogicBuilder.build_input()`이 node config를 읽고 `logic_key`, `logic_parameters`를 검증한다.
2. `ensure_service_logic_registry_bootstrapped()`가 `agents/*/services/*/logics/*.py`를 import한다.
3. 각 logic module import 과정에서 schema의 `Contract` class가 `ServiceLogicContract` registry에 들어가고, logic 함수의 `@register_service_logic(...)` decorator가 `ServiceLogicRegistry`에 executor를 등록한다.
4. `resolve_service_logic(custom_parameters)`가 `logic_key`로 `ServiceLogicSpec`을 가져온다.
5. `ServiceLogicRunner`가 `ConfigRead`, `ContextRead`, `PrevNodeOutput` marker를 기반으로 typed `Input`을 구성한다.
6. executor가 `Output` model 또는 `NodeExecutionResult`를 반환한다.
7. `NextNodeOutput` marker와 `ContextWrite` marker가 각각 다음 payload와 workflow context update로 변환된다.

Now we can guarantee: 같은 agent subtype이라도 `logic_key`가 다르면 완전히 다른 schema, context rule, executor가 선택된다. 따라서 Logic Builder node를 진단할 때 첫 번째 key는 instance id가 아니라 `custom_parameters.logic_key`다.

### 4.3 Logic code bundle의 의미

여기서 "logic"은 함수 하나가 아니라 contract, typed I/O, executor, shared helper가 함께 움직이는 작은 code bundle이다.

```mermaid
flowchart TB
  KEY["logic_key<br/>예: lrm.case_search.build_risk_query"]

  subgraph SchemaFile["schemas/build_risk_query.py"]
    PARAM["Parameters<br/>FE Agent Setting config schema"]
    IN["Input<br/>ConfigRead / ContextRead / PrevNodeOutput"]
    OUT["Output<br/>NextNodeOutput / ContextWrite"]
    CONTRACT["Contract<br/>logic_key / display_name / description<br/>config_model / input_model / output_model"]
    PARAM --> CONTRACT
    IN --> CONTRACT
    OUT --> CONTRACT
  end

  subgraph LogicFile["logics/build_risk_query.py"]
    DEC["@register_service_logic(Contract.logic_key)"]
    FN["execute_build_risk_query(input, runtime)<br/>business transition"]
    DEC --> FN
  end

  subgraph SharedFiles["shared files in same service package"]
    COMMON["schemas/common.py<br/>shared input/output models<br/>domain normalizers"]
    HELP["logics/placeholder_utils.py<br/>template placeholder replacement"]
  end

  KEY --> CONTRACT
  CONTRACT --> DEC
  COMMON --> IN
  COMMON --> OUT
  HELP --> FN
  FN --> RESULT["Output model<br/>or NodeExecutionResult"]
```

파일별 기능은 다음처럼 나뉜다.

- `schemas/common.py`: 해당 service package 전체에서 공유하는 Pydantic base model, previous/next payload model, normalize helper를 둔다. `case_search`는 `SimilarProject`, `ProjectRiskGroup`, `RetrievedDocumentsOutput` 등을, `contract_vrb`는 `LoadedContractFilesOutput`, `MatchingResultOutput`, finding normalize 대상 model 등을 공유한다.
- `schemas/<logic>.py`: Agent Builder에 보일 설정 schema(`Parameters`), runtime input source(`Input`), node 종료 후 contract(`Output`), registry binding(`Contract`)을 정의한다.
- `logics/<logic>.py`: 실제 deterministic transition 또는 adapter 호출을 수행한다. 이 함수가 `@register_service_logic(Contract.logic_key)`로 registry에 들어간다.
- `logics/*utils*.py`: placeholder replacement, finding normalize/dedupe처럼 여러 logic이 공유하지만 독립적으로 테스트 가능한 순수 helper를 둔다.

Now we can guarantee: schema 파일만 보면 node가 무엇을 읽고 무엇을 보장하는지 알 수 있고, logic 파일을 보면 그 보장을 만들기 위해 어떤 변환을 수행하는지 알 수 있다.

### 4.4 Input source와 output target 규칙

Logic Builder는 source marker와 output marker를 기준으로 data lane을 분리한다.

```mermaid
flowchart TB
  subgraph InputSource["Input marker -> typed field"]
    CFG["ConfigRead('source_config')"]
    LP["custom_parameters.logic_parameters.source_config"]
    CP["custom_parameters.source_config"]
    CM["common_parameters.source_config"]
    CFG --> LP --> CP --> CM

    CTXR["ContextRead('workflow.project_id')"]
    C1["context_parameters.project_id"]
    C2["context_parameters.workflow.project_id"]
    C3["context_parameters.project_id<br/>after root strip / leaf fallback"]
    CTXR --> C1 --> C2 --> C3

    PREVR["PrevNodeOutput(Model, path='documents')"]
    P1["prev_result.documents"]
    P2["prev_result field fallback"]
    PREVR --> P1 --> P2
  end

  subgraph OutputTarget["Output marker -> runtime result"]
    MODEL["schema.Output model"]
    HAS{"NextNodeOutput<br/>exists?"}
    EX["payload = explicit NextNodeOutput fields"]
    IM["payload = non-ContextWrite fields"]
    CW["ContextWrite fields/class<br/>dotted context_updates"]
    BOTH["ContextWrite(..., next_node=True)<br/>payload + context update"]
    MODEL --> HAS
    HAS -->|yes| EX
    HAS -->|no| IM
    MODEL -.-> CW
    MODEL -.-> BOTH
  end
```

Now we can guarantee: `payload`와 `context_updates`는 executor가 임의로 섞어 반환하는 값이 아니라 marker가 붙은 `Output` model에서 기계적으로 파생된다. 예외적으로 executor가 직접 `NodeExecutionResult`를 반환하면 그 결과가 우선한다.

### 4.5 Logic Builder와 다른 node/component의 관계

`lrm_service3`와 `lrm_service6`는 Logic Builder만으로 끝나지 않는다. Logic Builder node가 payload를 준비하고 정규화하면, retriever/LLM/selector 같은 다른 agent node가 그 contract를 소비한다.

```mermaid
flowchart TB
  subgraph WorkflowDB["workflow definition"]
    SW["service_workflow DAG"]
    AI["agent_instance settings"]
    SW --> AI
  end

  subgraph RuntimeAgents["runtime agent types"]
    LB["Logic Builder<br/>Python service logic"]
    RET["Retriever<br/>OpenSearch RAW search"]
    SEL["Flow Selector<br/>branch decision"]
    LLM["Prompt / LongText LLM<br/>Bedrock prompt execution"]
  end

  subgraph External["external stores and services"]
    OS[("OpenSearch")]
    PG[("PostgreSQL")]
    S3[("S3 converted JSON")]
    BR["Bedrock"]
  end

  AI --> LB
  AI --> RET
  AI --> SEL
  AI --> LLM
  LB -->|prepare search body / merge / render| RET
  RET -->|documents array| LB
  LB -->|branch field| SEL
  LB -->|prompt payload / chunk plan| LLM
  LLM -->|raw response| LB
  RET --> OS
  LB --> PG
  LB --> S3
  LLM --> BR
  LB --> BR
```

Now we can guarantee: Logic Builder는 workflow의 모든 일을 직접 처리하는 agent가 아니라, 외부 호출 node 전후의 data contract를 안정화하는 접착층이다. 장애 분석에서는 "Logic Builder가 만든 입력이 틀렸는가", "외부 node 응답이 틀렸는가", "후처리 Logic Builder가 응답을 잘못 정규화했는가"를 분리해서 봐야 한다.

### 4.6 `lrm_service3` Logic Builder key map

```mermaid
flowchart TB
  subgraph CaseSearch["agents/lrm/services/case_search"]
    CCOMMON["schemas/common.py<br/>CaseSearchInput/Output<br/>RetrievedDocumentsOutput<br/>SimilarProject / Risk models"]
    PH["logics/placeholder_utils.py<br/>{{query}}, {{query_vector}}, {{project_ids}}, {{filters}}"]

    L1["lrm.case_search.build_project_query<br/>900<br/>project search_body + target_project"]
    L2["lrm.case_search.build_risk_query<br/>902<br/>risk search_body + similar_projects"]
    L3["lrm.case_search.extract_risks<br/>904<br/>risk documents -> projects_draft<br/>formatting branch field"]
    L4["lrm.case_search.select_format_targets<br/>907<br/>context draft -> LLM formatting payload"]
    L5["lrm.case_search.merge_formatted<br/>908<br/>LLM formatted subset -> merged draft"]
    L6["lrm.case_search.passthrough_risks<br/>909<br/>skip formatting branch"]
    L7["lrm.case_search.render_document<br/>910<br/>metadata.projects[] contract"]

    CCOMMON --> L1
    CCOMMON --> L2
    CCOMMON --> L3
    CCOMMON --> L4
    CCOMMON --> L5
    CCOMMON --> L6
    CCOMMON --> L7
    PH --> L1
    PH --> L2
  end

  L1 --> R1["901 Retriever<br/>lrm_review_project"]
  R1 --> L2
  L2 --> R2["903 Retriever<br/>lrm_review_risk_opinion"]
  R2 --> L3
  L3 --> S["906 Flow Selector"]
  S --> L4 --> F["905 LLM formatter"] --> L5 --> L7
  S --> L6 --> L7
```

대표 sandbox: node 3 `build_risk_query`는 앞 node의 project search 결과를 risk search request로 바꾸는 좁은 전환점이다.

```mermaid
flowchart LR
  subgraph Before["Before node 3"]
    PDOC["prev payload<br/>project documents[]"]
    CTX1["context<br/>shared.project_id<br/>shared.role_codes<br/>workflow.vrb_type"]
    CFG1["logic_parameters.source_config<br/>RAW risk search template"]
  end

  subgraph Transition["lrm.case_search.build_risk_query"]
    EXT["extract project_id/name/score"]
    EXC["exclude current project"]
    LIM["take max 5"]
    FIL["build table_type / vrb_type / role filters"]
    BODY["replace {{project_ids}} and {{filters}}"]
    NONE["fallback match_none when no candidates"]
    EXT --> EXC --> LIM --> FIL --> BODY
    LIM --> NONE
  end

  subgraph After["After node 3"]
    NEXT["next payload<br/>search_body"]
    CWRITE[("context write<br/>shared.case_search.similar_projects")]
  end

  PDOC --> EXT
  CTX1 --> EXC
  CTX1 --> FIL
  CFG1 --> BODY
  BODY --> NEXT
  NONE --> NEXT
  LIM -.-> CWRITE
```

Now we can guarantee: risk retriever는 OpenSearch RAW query body를 항상 받는다. 유사 프로젝트가 없으면 empty failure가 아니라 `match_none` query로 넘어가므로, 뒤 node는 "검색 결과 없음"을 정상 data state로 처리할 수 있다.

### 4.7 `lrm_service6` Logic Builder key map

```mermaid
flowchart TB
  subgraph ContractVrb["agents/lrm/services/contract_vrb"]
    VCOMMON["schemas/common.py<br/>ContractVrbInput/Output<br/>LoadedContractFilesOutput<br/>MatchingResultOutput"]
    NORM["logics/utils/finding_normalize.py<br/>finding normalize / dedupe / source cleanup"]

    V1["lrm.contract_vrb.context_resolver<br/>950<br/>project/generation context"]
    V2["lrm.contract_vrb.contract_source_loader<br/>951<br/>PostgreSQL + S3 -> files[]"]
    V3["lrm.contract_vrb.document_planner<br/>953<br/>files[] -> chunk plan"]
    V4["lrm.contract_vrb.anchor_preparer<br/>954<br/>standard_item -> checklist anchors"]
    V5["lrm.contract_vrb.findings_merger<br/>956<br/>anchored/plain LLM -> canonical findings"]
    V6["lrm.contract_vrb.category_synthesis_planner<br/>959<br/>findings -> anchored/plain synthesis payload"]
    V7["lrm.contract_vrb.category_merger<br/>961<br/>category LLM -> merged findings"]
    V8["lrm.contract_vrb.final_renderer<br/>957<br/>## III. 검토의견 final payload"]

    VCOMMON --> V1
    VCOMMON --> V2
    VCOMMON --> V3
    VCOMMON --> V4
    VCOMMON --> V5
    VCOMMON --> V6
    VCOMMON --> V7
    VCOMMON --> V8
    NORM --> V5
    NORM --> V7
    NORM --> V8
  end

  V1 --> V2 --> V3
  V3 --> V4 --> A["955 LongText LLM<br/>anchored matching"] --> V5
  V3 --> P["958 LongText LLM<br/>plain matching"] --> V5
  V5 --> V6
  V6 --> CA["960 LLM<br/>anchored category synthesis"] --> V7
  V6 --> CP["965 LLM<br/>plain category synthesis"] --> V7
  V7 --> V8
```

대표 sandbox: category synthesis 구간은 fan-in 이후 다시 anchored/plain branch로 fan-out했다가 merge-back하는 지점이다.

```mermaid
flowchart TB
  subgraph Before["Before node 7"]
    FIND["prev payload<br/>canonical findings[]"]
    SRCMETA["finding source tags<br/>anchored / plain<br/>category / evidence_ids"]
  end

  subgraph Planner["lrm.contract_vrb.category_synthesis_planner"]
    IDX["assign stable global idx"]
    GRP["group by source + category"]
    SPLIT["split multi-member groups only"]
    KEEP["store originals in context<br/>source_findings"]
    APAY["next payload<br/>anchored_payload"]
    PPAY["next payload<br/>plain_payload"]
    IDX --> GRP --> SPLIT
    SPLIT --> APAY
    SPLIT --> PPAY
    IDX -.-> KEEP
  end

  subgraph ExternalLLM["category synthesis LLM"]
    ALLM["960 anchored synthesis"]
    PLLM["965 plain synthesis"]
  end

  subgraph MergeBack["node 9 category_merger"]
    RESTORE["restore originals by idx"]
    MERGED["merged findings[]"]
  end

  FIND --> IDX
  SRCMETA --> GRP
  APAY --> ALLM --> RESTORE
  PPAY --> PLLM --> RESTORE
  KEEP -.-> RESTORE --> MERGED
```

Now we can guarantee: category synthesis LLM에는 병합 후보인 multi-member group만 보낸다. single finding은 context에 저장된 원본에서 복원되므로, LLM이 필요 없는 항목을 다시 쓰면서 provenance를 훼손할 가능성을 줄인다.

## 5. Agent Builder node 단위 실행

FE Agent Builder는 workflow 전체 실행 전후를 쪼개서 확인하는 가장 좋은 화면이다.

![Agent Builder example](assets/lrm_service3_lrm_service6_handover/lrm-service3-agent-builder.png)

node 단위 실행은 대략 다음 흐름이다.

```mermaid
flowchart LR
  UI["Agent Builder<br/>node 실행 버튼"] --> H["useNodeExecution"]
  H --> PR["parent result 수집<br/>prev_results_map"]
  H --> IC["Initial Workflow Context<br/>JSON parse"]
  H --> ASI["agent_setting_info<br/>current node instance"]
  PR --> API["node execute API"]
  IC --> API
  ASI --> API
  API --> RES["node response"]
  API -.-> SNAP["context_snapshot"]
```

직접 HTTP로 재현할 때 핵심 envelope는 아래 형태다. FE의 TypeScript 타입은 camelCase지만 `apiClient`가 request body를 snake_case로 변환하므로, curl/Postman에서 BE를 직접 호출할 때는 snake_case를 사용한다.

```json
{
  "user_id": "debug-user",
  "agent_setting_info": {
    "agent_id": 900,
    "agent_name": "리스크 추출 및 포매팅 대상 선정",
    "agent_type": "UTIL",
    "agent_sub_type": "util_agent_logic_builder",
    "node_type": "agent",
    "node_reference_id": "904",
    "common_parameters": {},
    "custom_parameters": {
      "logic_key": "lrm.case_search.extract_risks",
      "logic_parameters": {}
    }
  },
  "user_input": {
    "query": "",
    "service_id": "lrm_service3",
    "channel_id": "handover-debug"
  },
  "initial_workflow_context": {
    "project_name": "샘플 프로젝트"
  },
  "prev_results_map": {
    "retriever_agent_iam_opensearch_common": {
      "documents": []
    }
  }
}
```

Now we can guarantee: 중간 node 재현 시 `prev_results_map`에는 부모 node payload를, `initial_workflow_context`에는 해당 node가 `ContextRead`로 읽는 workflow 값을 넣어야 한다. 둘 중 하나가 빠지면 node 자체는 실행되어도 실제 workflow와 다른 상태를 재현하게 된다.

## 6. 화면 캡처와 운영 확인 지점

아래 화면은 workflow 구조와 node 단위 실행을 확인할 때 사용하는 운영 evidence다.

| 캡처 | 용도 |
| --- | --- |
| `assets/lrm_service3_lrm_service6_handover/lrm-service3-workflow-tab.png` | `lrm_service3` service detail 구성 탭 |
| `assets/lrm_service3_lrm_service6_handover/lrm-service3-agent-builder.png` | `lrm_service3` Agent Builder node 실행 입력 |
| `assets/lrm_service3_lrm_service6_handover/lrm-service6-workflow-tab.png` | `lrm_service6` service detail 구성 탭 |
| `assets/lrm_service3_lrm_service6_handover/lrm-service6-agent-builder.png` | `lrm_service6` Agent Builder node 실행 입력 |
| `assets/lrm_service3_lrm_service6_handover/agent-swagger-internal-endpoints.png` | agent server internal workflow/node/logic API |

## 7. 공통 API / DB 확인

agent server Swagger의 internal endpoint에서 node 단위 실행과 Logic Builder schema를 확인할 수 있다.

![agent Swagger internal endpoints](assets/lrm_service3_lrm_service6_handover/agent-swagger-internal-endpoints.png)

주요 endpoint:

```text
POST /internal/workflow/execute
POST /internal/agents/node/execute
GET  /internal/logic/catalog
GET  /internal/logic/schema
POST /lrm/workflow/execute
```

workflow DAG 확인:

```sql
select service_id, node_id, node_reference_id, next_node_ids::text
from irax.service_workflow
where service_id in ('lrm_service3', 'lrm_service6')
order by service_id, position;
```

Logic Builder instance 확인:

```sql
select id, name, agent_id, custom_parameters->>'logic_key' as logic_key
from irax.agent_instance
where id in (900,902,904,907,908,909,910,950,951,953,954,956,957,959,961)
order by id;
```

LLM / retriever / selector instance 확인:

```sql
select ai.id, ai.name, ai.agent_id, a.agent_sub_type
from irax.agent_instance ai
join irax.agent a on a.id = ai.agent_id
where ai.id in (901,903,905,906,955,958,960,965)
order by ai.id;
```

## 8. 장애 위치를 좁히는 기준

workflow 문제는 service id에서 시작해 DAG, node transition, 실행 결과, 저장소 상태 순서로 좁힌다.

```mermaid
flowchart LR
  A["FE 요청<br/>service_id"] --> B["workflow DAG"]
  B --> C["node별<br/>payload / context transition"]
  C --> D["Agent Builder<br/>node 단위 실행"]
  D --> E["DB / API<br/>저장 상태 확인"]
  E --> F["문제 node 또는<br/>data contract 특정"]
```

Now we can guarantee: 운영자는 service workflow의 전체 구현을 모두 외우지 않아도 각 node 종료 시점의 data contract를 기준으로 문제 위치를 좁힐 수 있다.
