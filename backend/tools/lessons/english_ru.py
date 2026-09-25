"""Уроки EduApp по английскому языку: правила объясняются по-русски, примеры и упражнения — на английском."""
from tools.lessons.model import L, s

SUBJECT = "english"
LANGUAGE = "ru"

TOPICS_TJ = {
    "Как устроен субтест «Английский язык»": "Субтести «Забони англисӣ» чӣ гуна сохта шудааст",
    "Present Simple и Present Continuous": "Present Simple ва Present Continuous",
    "Прошедшие времена": "Замонҳои гузашта",
    "Present Perfect и будущее время": "Present Perfect ва замони оянда",
    "Страдательный залог": "Ҳолати мафъулӣ",
    "Условные предложения": "Ҷумлаҳои шартӣ",
    "Модальные глаголы": "Феълҳои модалӣ",
    "Косвенная речь": "Нутқи ғайримустақим",
    "Словообразование и фразовые глаголы": "Калимасозӣ ва феълҳои фразеологӣ",
    "Чтение и понимание текста": "Хониш ва фаҳмиши матн",
}

LESSONS = [
    L("Как устроен субтест «Английский язык»", "Как устроен субтест и как к нему готовиться", """
# Как устроен субтест «Английский язык»

**25 заданий**: 20 с выбором ответа и 5 на соответствие. Максимум — **40 очков**.

## Три части
| Часть | Что проверяют |
|---|---|
| Reading comprehension | понимание текста: главная мысль, детали, значение слова по контексту |
| Grammar | времена, залог, условные предложения, модальные глаголы, косвенная речь |
| Vocabulary / practical items | значения слов, устойчивые сочетания, фразовые глаголы, словообразование |

## Как готовиться
1. **Грамматика по схемам.** Для каждого времени запомните формулу и слова-маркеры (always, now, yesterday,
   since, by the time).
2. **Слова — в сочетаниях**: make a mistake, do homework, heavy traffic, pay attention.
3. **Читайте каждый день** короткие тексты (новости, рассказы) и пересказывайте главную мысль одним
   предложением.

## Как решать задания на пропуск
Сначала найдите **слова-подсказки** в предложении (маркеры времени, предлоги, союзы), затем проверьте
вариант, подставив его в предложение целиком.
""",
      [s("easy", "Which word is a time marker of Present Continuous?", "now", ["yesterday", "usually", "ago"],
         "now, at the moment, look! — признаки действия, происходящего сейчас."),
       s("medium", "Choose the correct collocation.", "make a mistake", ["do a mistake", "take a mistake",
                                                                          "get a mistake"],
         "Устойчивое сочетание: make a mistake."),
       s("medium", "Сколько заданий на соответствие в субтесте «Английский язык»?", "5", ["4", "2", "0"],
         "20 заданий с выбором ответа и 5 на соответствие.")],
      [s("hard", "Which marker is typical of Present Perfect?", "since", ["yesterday", "last week", "in 2010"],
         "since и for, already, yet, just — маркеры Present Perfect; yesterday, last week — Past Simple."),
       s("hard", "Choose the correct collocation: Please, ___ attention to the board.", "pay",
         ["make", "do", "give"], "Устойчивое сочетание: pay attention."),
       s("hard", "Choose the correct collocation: I have to ___ my homework.", "do", ["make", "take", "get"],
         "do homework, do exercises, do the shopping."),
       s("hard", "What is the best first step when you see a gap in a sentence?", "find the clue words in the "
                                                                                 "sentence",
         ["choose the longest option", "choose option A", "skip the task"],
         "Маркеры времени, предлоги и союзы подсказывают правильную форму."),
       s("hard", "Choose the correct collocation: There was ___ rain last night.", "heavy", ["strong", "big",
                                                                                           "thick"],
         "heavy rain, heavy traffic — устойчивые сочетания."),
       s("hard", "What does «the main idea of the text» mean?", "the most important point of the whole text",
         ["the first sentence", "the longest paragraph", "a detail from the text"],
         "Главная мысль охватывает весь текст, а не отдельную деталь.")]),

    L("Present Simple и Present Continuous", "Present Simple и Present Continuous: регулярное и происходящее сейчас",
      """
# Present Simple и Present Continuous

## Present Simple — факты, привычки, расписания
- Утверждение: I/you/we/they **work**; he/she/it **works** (окончание **-s**!).
- Отрицание и вопрос с **do/does**: She doesn't work. Does she work?
- Маркеры: always, usually, often, sometimes, never, every day.
- Расписания: The train **leaves** at 6.

## Present Continuous — действие сейчас или временное
- am/is/are + V-ing: She **is reading** now.
- Маркеры: now, at the moment, Look!, Listen!, this week.
- Планы на ближайшее будущее: We **are meeting** him tomorrow.

## Глаголы состояния
Know, like, love, want, understand, believe, own, need **не употребляются** в Continuous:
~~I am knowing~~ → I **know**.

## Сравните
- He **plays** football every Sunday. (привычка)
- He **is playing** football now. (сейчас)
""",
      [s("easy", "She ___ to school every day.", "goes", ["go", "is going", "going"],
         "Регулярное действие (every day), третье лицо — окончание -es."),
       s("medium", "Look! The children ___ in the garden.", "are playing", ["play", "plays", "played"],
         "Look! — действие происходит в момент речи, Present Continuous."),
       s("medium", "I ___ what you mean.", "understand", ["am understanding", "understands", "am understand"],
         "understand — глагол состояния, в Continuous не используется.")],
      [s("hard", "The film ___ at 7 p.m., so let's hurry.", "starts", ["is starting now", "start", "starting"],
         "Расписание — Present Simple."),
       s("hard", "___ your brother ___ in a bank?", "Does ... work", ["Do ... work", "Is ... work",
                                                                      "Does ... works"],
         "Вопрос в Present Simple для he/she/it — does + глагол без -s."),
       s("hard", "We ___ our grandparents tomorrow — the tickets are already bought.", "are visiting",
         ["visit", "visits", "visited"], "Запланированное на ближайшее будущее — Present Continuous."),
       s("hard", "She usually ___ tea, but today she ___ coffee.", "drinks ... is drinking",
         ["is drinking ... drinks", "drink ... drinking", "drinks ... drinks"],
         "usually — привычка (Simple), today — временная ситуация (Continuous)."),
       s("hard", "He ___ a new car. (to own)", "owns", ["is owning", "own", "owning"],
         "own — глагол состояния."),
       s("hard", "Water ___ at 100 °C.", "boils", ["is boiling", "boil", "boiled"],
         "Научный факт — Present Simple.")]),

    L("Прошедшие времена", "Past Simple, Past Continuous, Past Perfect, used to", """
# Прошедшие времена

## Past Simple — завершённое действие в прошлом
- Правильные глаголы: + **-ed** (worked); неправильные — вторая форма (go — **went**, see — **saw**).
- Вопрос и отрицание с **did**: Did you see him? I didn't see him.
- Маркеры: yesterday, last year, ago, in 2020.

## Past Continuous — процесс в момент прошлого
- was/were + V-ing: At 8 p.m. I **was watching** TV.
- Длительное действие прерывается кратким: I **was reading** when he **came**.

## Past Perfect — «предпрошедшее»
- had + V3: When we arrived, the film **had started**.
- Маркеры: before, by the time, already (в прошлом).

## used to — привычка в прошлом
I **used to play** chess (раньше играл, теперь нет). Не путать с **be used to + V-ing** (привык):
I'm used to getting up early.
""",
      [s("easy", "I ___ my grandmother last Sunday.", "visited", ["visit", "have visited", "was visit"],
         "last Sunday — завершённое действие в прошлом, Past Simple."),
       s("medium", "When the phone rang, I ___ a shower.", "was taking", ["took", "take", "had taken"],
         "Длительное действие прервано звонком — Past Continuous."),
       s("medium", "By the time we arrived, the train ___.", "had left", ["left", "has left", "was leaving"],
         "Действие завершилось до другого момента в прошлом — Past Perfect.")],
      [s("hard", "She ___ in Dushanbe when she was a child.", "used to live", ["is used to live", "use to lived",
                                                                               "used to living"],
         "Привычка или состояние в прошлом — used to + V."),
       s("hard", "Did you ___ the news yesterday?", "hear", ["heard", "hears", "hearing"],
         "После did — глагол в начальной форме."),
       s("hard", "While I ___ dinner, my brother ___ his homework.", "was cooking ... was doing",
         ["cooked ... did", "was cooking ... did", "cook ... was doing"],
         "Два параллельных длительных процесса в прошлом — Past Continuous."),
       s("hard", "The past form of «bring» is", "brought", ["bringed", "brang", "brung"],
         "bring — brought — brought (неправильный глагол)."),
       s("hard", "He said he ___ that film before.", "had seen", ["saw", "has seen", "sees"],
         "Действие раньше другого прошедшего действия — Past Perfect."),
       s("hard", "I ___ to school by bus, but now I walk.", "used to go", ["am used to go", "use to go",
                                                                           "used to going"],
         "Раньше было, сейчас нет — used to + V.")]),

    L("Present Perfect и будущее время", "Present Perfect, Future Simple, be going to, Future Perfect", """
# Present Perfect и будущее время

## Present Perfect
- have/has + V3: I **have finished**.
- Результат к настоящему моменту, опыт: Have you ever **been** to London?
- Маркеры: already, yet, just, ever, never, since, for, recently, this week.
- **Не употребляется** с точным прошедшим временем: ~~I have seen him yesterday~~ → I **saw** him yesterday.
- Present Perfect Continuous (have been + V-ing): действие длится до сих пор — I **have been learning**
  English for 3 years.

## Будущее время
| Форма | Когда | Пример |
|---|---|---|
| will + V | решение в момент речи, прогноз | I'll help you. |
| be going to + V | план, намерение; признаки сейчас | Look at the clouds! It's going to rain. |
| Present Continuous | договорённость | I'm meeting Ali at 5. |
| will have + V3 (Future Perfect) | завершится к моменту в будущем | By 2030 I will have graduated. |

## Время в придаточных времени и условия
После when, if, before, after, as soon as будущее выражается **Present Simple**: I'll call you when I **arrive**.
""",
      [s("easy", "I have ___ my homework already.", "done", ["did", "do", "doing"],
         "Present Perfect: have + третья форма глагола (do — did — done)."),
       s("medium", "I ___ him yesterday.", "saw", ["have seen", "see", "had saw"],
         "Точное время в прошлом (yesterday) — Past Simple."),
       s("medium", "I'll phone you when I ___ home.", "get", ["will get", "got", "am getting"],
         "В придаточном времени после when — Present Simple вместо будущего.")],
      [s("hard", "She ___ English for five years and still studies it.", "has been learning",
         ["learns", "learned", "is learning"], "Действие началось в прошлом и продолжается — Present Perfect "
                                              "Continuous."),
       s("hard", "Look at those black clouds! It ___.", "is going to rain", ["will rain", "rains", "rained"],
         "Есть признаки в настоящем — be going to."),
       s("hard", "By next June, I ___ school.", "will have finished", ["will finish", "finish", "have finished"],
         "Завершится к моменту в будущем — Future Perfect."),
       s("hard", "Have you ___ been to Samarkand?", "ever", ["yet", "since", "ago"],
         "ever — «когда-либо» в вопросах о жизненном опыте."),
       s("hard", "The phone is ringing. — I ___ it!", "'ll answer", ["am going to answer", "answer",
                                                                      "have answered"],
         "Решение, принятое в момент речи, — will."),
       s("hard", "We have lived here ___ 2015.", "since", ["for", "from", "ago"],
         "since + момент начала, for + период (for ten years).")]),

    L("Страдательный залог", "Passive Voice: формы и употребление", """
# Страдательный залог (Passive Voice)

## Формула
**be (в нужном времени) + V3**. Используется, когда важен сам факт или объект, а не исполнитель.
Исполнитель вводится предлогом **by**: The book was written **by** Tolstoy.

## Таблица форм
| Время | Пассив | Пример |
|---|---|---|
| Present Simple | am/is/are + V3 | English **is spoken** here. |
| Past Simple | was/were + V3 | The bridge **was built** in 2010. |
| Present Continuous | am/is/are being + V3 | The road **is being repaired**. |
| Present Perfect | have/has been + V3 | The letter **has been sent**. |
| Future Simple | will be + V3 | The results **will be announced** tomorrow. |
| с модальным | modal + be + V3 | The work **must be done** today. |

## Как узнать пассив
Подлежащее **не выполняет** действие: The window was broken (окно разбили).

## Частые ошибки
- Пропуск глагола be: ~~The house built in 1990~~ → The house **was** built in 1990.
- Неверная третья форма: write — wrote — **written**.
""",
      [s("easy", "The letter ___ yesterday.", "was sent", ["sent", "is sent", "was send"],
         "Past Simple Passive: was/were + V3."),
       s("medium", "English ___ in many countries.", "is spoken", ["speaks", "is speaking", "spoken"],
         "Present Simple Passive: is + V3."),
       s("medium", "The road ___ at the moment, so we can't drive there.", "is being repaired",
         ["is repaired", "repairs", "was repaired"], "Процесс сейчас — Present Continuous Passive.")],
      [s("hard", "The results ___ next week.", "will be announced", ["will announce", "are announced",
                                                                      "announced"],
         "Future Simple Passive: will be + V3."),
       s("hard", "This work must ___ today.", "be done", ["do", "been done", "be do"],
         "Модальный глагол + be + V3."),
       s("hard", "«Hamlet» ___ by Shakespeare.", "was written", ["wrote", "was wrote", "has written"],
         "Исполнитель после by, форма written."),
       s("hard", "Three new schools ___ in our city since 2020.", "have been built", ["were built",
                                                                                      "have built", "are built"],
         "since — Present Perfect Passive: have been + V3."),
       s("hard", "Which sentence is in the passive voice?", "The cake was eaten by the children.",
         ["The children ate the cake.", "The children are eating the cake.", "The children have eaten the cake."],
         "Подлежащее (cake) не выполняет действие."),
       s("hard", "The thief ___ by the police last night.", "was caught", ["caught", "was catched", "is caught"],
         "catch — caught — caught; last night — Past Simple Passive.")]),

    L("Условные предложения", "Conditionals: нулевой, первый, второй, третий типы; I wish", """
# Условные предложения

| Тип | Когда | Схема | Пример |
|---|---|---|---|
| Zero | общая истина | If + Present, Present | If you heat ice, it **melts**. |
| First | реальное будущее | If + Present, will + V | If it **rains**, we **will stay** home. |
| Second | нереальное настоящее | If + Past, would + V | If I **were** rich, I **would travel**. |
| Third | нереальное прошлое | If + Past Perfect, would have + V3 | If he **had studied**, he **would have passed**. |

- Во втором типе с I/he/she употребляется **were**: If I were you…
- В части с if **не бывает will**: ~~If it will rain~~.
- **Смешанный тип**: If I **had studied** harder (прошлое), I **would have** a better job now (настоящее).
- **Unless** = if not: I won't go unless you come.

## I wish
- Сожаление о настоящем: I wish I **knew** the answer.
- Сожаление о прошлом: I wish I **hadn't said** that.
- Недовольство чужим поведением: I wish you **would stop** talking.
""",
      [s("easy", "If it rains tomorrow, we ___ at home.", "will stay", ["stay", "would stay", "stayed"],
         "Реальное условие в будущем — First Conditional."),
       s("medium", "If I ___ you, I would apologise.", "were", ["am", "will be", "had been"],
         "Second Conditional: If I were you."),
       s("medium", "If he had left earlier, he ___ the train.", "wouldn't have missed", ["won't miss",
                                                                                          "wouldn't miss",
                                                                                          "didn't miss"],
         "Third Conditional: would have + V3.")],
      [s("hard", "If you mix red and white, you ___ pink.", "get", ["will got", "would get", "got"],
         "Общая истина — Zero Conditional."),
       s("hard", "I wish I ___ more free time now.", "had", ["have", "will have", "had had"],
         "Сожаление о настоящем — I wish + Past Simple."),
       s("hard", "I won't help you ___ you ask politely.", "unless", ["if", "when", "because"],
         "unless = if not: не помогу, если не попросишь вежливо."),
       s("hard", "If she ___ the instructions, she wouldn't have made the mistake.", "had read",
         ["read", "has read", "would read"], "Third Conditional: If + Past Perfect."),
       s("hard", "I wish I ___ so much yesterday.", "hadn't eaten", ["didn't eat", "don't eat", "won't eat"],
         "Сожаление о прошлом — I wish + Past Perfect."),
       s("hard", "If I ___ harder at school, I would be a doctor now.", "had studied", ["studied",
                                                                                        "would study", "study"],
         "Смешанный тип: условие в прошлом, результат в настоящем.")]),

    L("Модальные глаголы", "Модальные глаголы: can, must, have to, should, may, might, need", """
# Модальные глаголы

| Глагол | Значение | Пример |
|---|---|---|
| can / could | умение, возможность, просьба | I can swim. Could you help me? |
| must | необходимость (мнение говорящего), уверенность | You must see this film. He must be tired. |
| have to | необходимость по обстоятельствам | I have to get up at 6. |
| mustn't | запрет | You mustn't smoke here. |
| don't have to / needn't | нет необходимости | You don't have to come. |
| should | совет | You should see a doctor. |
| may / might | разрешение, предположение | It might rain. |

## После модальных — глагол без to
~~You must to go~~ → You **must go**. Исключения: have to, ought to, be able to.

## Модальные с перфектом (о прошлом)
- **must have + V3** — наверняка было: He must have forgotten.
- **can't have + V3** — не может быть, чтобы было: You can't have seen him — he was abroad.
- **should have + V3** — следовало, но не сделал: You should have told me.
- **needn't have + V3** — сделал зря: You needn't have bought milk.
""",
      [s("easy", "You ___ smoke here. It's forbidden.", "mustn't", ["don't have to", "needn't", "can"],
         "Запрет выражается глаголом mustn't («нельзя»)."),
       s("medium", "You look ill. You ___ see a doctor.", "should", ["mustn't", "can't", "needn't"],
         "Совет выражается глаголом should («следует»)."),
       s("medium", "Choose the correct sentence.", "She can play the piano.", ["She can to play the piano.",
                                                                              "She cans play the piano.",
                                                                              "She can plays the piano."],
         "После can — глагол без to и без окончания.")],
      [s("hard", "It's Sunday. You ___ get up early.", "don't have to", ["mustn't", "can't", "shouldn't"],
         "Нет необходимости — don't have to (mustn't означало бы запрет)."),
       s("hard", "He isn't answering. He ___ asleep.", "must be", ["can be", "should be", "has to be"],
         "Уверенное предположение — must be."),
       s("hard", "You ___ told me earlier! Now it's too late.", "should have", ["must have", "can't have",
                                                                               "needn't have"],
         "Упрёк о прошлом: следовало, но не сделал."),
       s("hard", "She ___ written this letter — she can't write in English.", "can't have",
         ["must have", "should have", "needn't have"], "Уверенность, что в прошлом этого не было."),
       s("hard", "We ___ bought so much bread — nobody was hungry.", "needn't have", ["mustn't have",
                                                                                     "can't have", "should have"],
         "Сделали, но в этом не было необходимости."),
       s("hard", "___ you open the window, please?", "Could", ["Must", "Should", "Need"],
         "Вежливая просьба — Could you…?")]),

    L("Косвенная речь", "Reported Speech: согласование времён, вопросы, просьбы", """
# Косвенная речь (Reported Speech)

## Согласование времён (если вводный глагол в прошедшем: said, told, asked)
| Прямая речь | Косвенная речь |
|---|---|
| Present Simple: «I work» | Past Simple: he said he **worked** |
| Present Continuous: «I am working» | he said he **was working** |
| Past Simple / Present Perfect | Past Perfect: he said he **had worked** |
| will | **would** |
| can / may | could / might |

## Изменение слов
now → then; today → that day; tomorrow → **the next day**; yesterday → **the day before**; here → there;
this → that; ago → before.

## Вопросы
- Общий вопрос: **if/whether** + прямой порядок слов: «Do you like tea?» → She asked **if I liked** tea.
- Специальный вопрос: вопросительное слово + прямой порядок: «Where do you live?» → He asked **where I lived**.

## Просьбы и приказы
tell/ask + (not) **to** + V: «Close the door» → He told me **to close** the door. «Don't be late» → She asked me
**not to be** late.

## say и tell
say (something), tell **somebody** (something): He **told me** that… / He **said** that…
""",
      [s("easy", "«I am tired», she said. → She said she ___ tired.", "was", ["is", "has been", "will be"],
         "Present Simple → Past Simple."),
       s("medium", "«Where do you live?» he asked. → He asked where ___.", "I lived", ["did I live",
                                                                                    "do I live", "I live"],
         "В косвенном вопросе прямой порядок слов и сдвиг времени."),
       s("medium", "«I will call you tomorrow», he said. → He said he would call me ___.", "the next day",
         ["tomorrow", "yesterday", "the day before"], "tomorrow → the next day.")],
      [s("hard", "«Do you speak English?» she asked me. → She asked me ___ English.", "if I spoke",
         ["did I speak", "do I speak", "that I spoke"], "Общий вопрос — if/whether + прямой порядок."),
       s("hard", "«Don't open the window», the teacher said to us. → The teacher told us ___ the window.",
         "not to open", ["don't open", "not open", "to not opened"], "Отрицательная просьба — not to + V."),
       s("hard", "«I have lost my key», he said. → He said he ___ his key.", "had lost", ["has lost", "lost",
                                                                                         "was lost"],
         "Present Perfect → Past Perfect."),
       s("hard", "He ___ me that he was busy.", "told", ["said", "spoke", "asked"],
         "tell + кому: told me; said — без дополнения «кому»."),
       s("hard", "«I can swim», the boy said. → The boy said he ___ swim.", "could", ["can", "will",
                                                                                      "was able"],
         "В косвенной речи can меняется на could."),
       s("hard", "«I saw him yesterday», she said. → She said she had seen him ___.", "the day before",
         ["yesterday", "the next day", "tomorrow"], "yesterday → the day before.")]),

    L("Словообразование и фразовые глаголы", "Суффиксы, приставки, фразовые глаголы, ложные друзья", """
# Словообразование и фразовые глаголы

## Суффиксы
| Часть речи | Суффиксы | Примеры |
|---|---|---|
| существительные | -tion, -ment, -ness, -er/-or, -ity | construction, development, happiness, teacher, ability |
| прилагательные | -ful, -less, -able, -ous, -al, -ive | useful, careless, readable, dangerous, national, creative |
| наречия | -ly | quickly, carefully |
| глаголы | -ize, -en | organize, widen |

## Приставки со значением «не»
un- (unhappy), in-/im-/il-/ir- (incorrect, impossible, illegal, irregular), dis- (dislike).

## -ing и -ed прилагательные
The film was **boring** (вызывает скуку) — I was **bored** (испытываю скуку).

## Фразовые глаголы
| Глагол | Значение |
|---|---|
| look after | заботиться |
| look for | искать |
| give up | бросить (привычку), сдаться |
| put off | отложить |
| turn down | отказать, убавить звук |
| get on with | ладить |
| find out | узнать |
| run out of | закончиться (о запасах) |

## Ложные друзья
actual — фактический (не «актуальный»), magazine — журнал (не «магазин»), sympathetic — сочувствующий.
""",
      [s("easy", "Choose the noun: The ___ of the bridge took two years. (build)", "building", ["builder",
                                                                                              "built", "builds"],
         "После the и перед of нужно существительное: building — строительство."),
       s("medium", "Choose the opposite of «possible».", "impossible", ["unpossible", "inpossible",
                                                                       "dispossible"],
         "Перед p используется im-: impossible."),
       s("medium", "«Look after» means", "take care of", ["look for", "find", "look at"],
         "look after — заботиться.")],
      [s("hard", "The lecture was so ___ that I fell asleep.", "boring", ["bored", "bore", "boredom"],
         "-ing описывает то, что вызывает чувство."),
       s("hard", "We have run ___ of milk. Can you buy some?", "out", ["off", "up", "down"],
         "run out of — закончиться."),
       s("hard", "She was very ___ when she heard the news. (surprise)", "surprised", ["surprising",
                                                                                     "surprise", "surprisingly"],
         "-ed описывает чувство человека."),
       s("hard", "He decided to give ___ smoking.", "up", ["in", "off", "away"], "give up — бросить привычку."),
       s("hard", "Choose the adjective: This medicine is very ___ . (use)", "useful", ["usefully", "usage",
                                                                                      "user"],
         "Суффикс -ful образует прилагательное."),
       s("hard", "«Magazine» means", "a journal with articles and pictures", ["a shop", "a storehouse",
                                                                              "a market"],
         "Ложный друг: magazine — журнал, магазин — shop.")]),

    L("Чтение и понимание текста", "Стратегии чтения: главная мысль, детали, слово по контексту", """
# Чтение и понимание текста

## Порядок работы с текстом
1. Прочитайте **вопросы** — узнаете, что искать.
2. Просмотрите текст целиком: о чём он? Главная мысль часто в **первом или последнем абзаце**.
3. Для вопросов на детали найдите в тексте **ключевые слова** из вопроса (или их синонимы) и перечитайте
   это место внимательно.

## Типы вопросов
| Вопрос | Как отвечать |
|---|---|
| Main idea | выбирайте вариант, который охватывает **весь** текст, а не одну деталь |
| True / False / Not stated | ответ должен прямо следовать из текста, а не из ваших знаний |
| Meaning of a word | подставьте варианты в предложение, смотрите на соседние слова |
| Why does the author…? | ищите объяснение в соседних предложениях |

## Ловушки
- Вариант повторяет слова текста, но смысл искажён.
- Вариант верен в жизни, но в тексте этого нет.
- Слова-«усилители»: always, never, all, only — часто делают вариант неверным.

## Синонимы помогают
Текст: «The glacier is **retreating**». Вопрос: «The glacier is **getting smaller**».
""",
      [s("easy", "Where is the main idea of a text often found?", "in the first or the last paragraph",
         ["only in the title", "in the middle of the longest sentence", "in the questions"],
         "Авторы часто формулируют главную мысль во вступлении или заключении."),
       s("medium", "What should you read first when doing a reading task?", "the questions",
         ["the last word of the text", "only the title", "nothing, just guess"],
         "Вопросы подсказывают, какую информацию искать в тексте."),
       s("medium", "Which answer is usually correct for «What is the main idea?»",
         "the option that covers the whole text", ["the option with a small detail", "the longest option",
                                                   "the option with the word «always»"],
         "Главная мысль относится ко всему тексту.")],
      [s("hard", "The text says: «Few people came to the meeting.» Which statement is true?",
         "The meeting was not well attended.", ["Nobody came to the meeting.", "Many people came.",
                                               "The meeting was cancelled."],
         "few — «мало» (но не «никто»)."),
       s("hard", "The text says: «He hardly slept last night.» This means he", "slept very little",
         ["slept a lot", "slept hard", "didn't want to sleep"], "hardly — «едва, почти не»."),
       s("hard", "The text says: «The price rose sharply.» The word «sharply» means", "quickly and strongly",
         ["slowly", "a little", "clearly"], "rise sharply — резко вырасти."),
       s("hard", "Which word often makes an option wrong in True/False tasks?", "always", ["sometimes",
                                                                                      "often", "some"],
         "Категоричные слова (always, never, all) редко подтверждаются текстом полностью."),
       s("hard", "The text says: «Despite the rain, the match went on.» What happened?",
         "The match continued in spite of the rain.", ["The match was stopped because of the rain.",
                                                        "It didn't rain.", "The match started after the rain."],
         "despite — «несмотря на»."),
       s("hard", "The text says: «The museum is closed on Mondays.» Which question can you answer?",
         "Can I visit the museum on Monday?", ["How much is a ticket?", "When was the museum built?",
                                              "Who works at the museum?"],
         "В тексте есть только информация о выходном дне.")]),
]
