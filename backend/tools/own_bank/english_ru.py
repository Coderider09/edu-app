"""Авторские задания EduApp по английскому языку в формате ЦВЭ: 2 варианта по 20 + 5 заданий.

Задания на английском, разбор — на русском (язык интерфейса абитуриента). Тексты для чтения написаны для EduApp.
"""
from tools.own_bank.model import M, S

SUBJECT = "english"
LANGUAGE = "ru"

GRAM = "Grammar"
VOC = "Vocabulary"
READ = "Reading comprehension"

GLACIER = (
    "The Fedchenko Glacier in the Pamir Mountains of Tajikistan is one of the longest glaciers in the world "
    "outside the polar regions. It stretches for about 77 kilometres, and in places the ice is more than "
    "900 metres thick. The glacier was named after the Russian naturalist Alexei Fedchenko, who explored "
    "Central Asia in the 1870s, although he never actually saw the glacier himself. It was first mapped "
    "in detail by an expedition in 1928.\n"
    "In 1933 a weather station was built near the glacier at an altitude of more than 4,000 metres. For decades, "
    "the scientists who lived there measured temperature and snowfall and watched the movement of the ice. "
    "Their records show that, like most mountain glaciers, Fedchenko has been retreating: its lower end has "
    "moved back by about a kilometre, and the glacier has become thinner.\n"
    "This matters far beyond the mountains. Meltwater from Pamir glaciers feeds rivers that millions of people "
    "downstream depend on for drinking water, farming and electricity. In the short term, faster melting can "
    "even increase the flow of rivers, but if the glaciers keep shrinking, there may eventually be much less "
    "water in the rivers during the dry summer months."
)

SLEEP = (
    "For a long time, sleep was seen as a passive state, a kind of 'switching off' of the brain. Research over "
    "the last few decades has shown that this is far from true. While we sleep, the brain is busy sorting the "
    "information collected during the day, strengthening some memories and letting others fade.\n"
    "In one well-known type of experiment, volunteers learn a list of words or a new skill in the evening. Half "
    "of them then sleep normally, while the other half stay awake all night. When both groups are tested the "
    "next day, those who have slept usually remember considerably more. Interestingly, even a short afternoon "
    "nap can bring some benefit, although it cannot replace a full night's rest.\n"
    "For students, the message is clear. Staying up all night before an exam may feel productive, but it often "
    "has the opposite effect: the material is poorly stored, and a tired brain finds it harder to concentrate "
    "and recall facts. Regular sleep, on the other hand, helps turn what we learn into lasting knowledge."
)

TASKS = [
    # ------------------------------------------------------------------ grammar
    S(GRAM, "hard",
      "By the time we arrived at the cinema, the film ___ for twenty minutes.",
      "had been running", ["was running", "has been running", "ran"],
      "Действие длилось до определённого момента в прошлом («к моменту, когда мы пришли») — Past Perfect Continuous. "
      "Present Perfect Continuous связан с настоящим и здесь не подходит."),
    S(GRAM, "hard",
      "If I ___ harder when I was at school, I would have a better job now.",
      "had studied", ["studied", "would study", "have studied"],
      "Смешанное условное: условие в прошлом (when I was at school) → Past Perfect, результат в настоящем (now) → "
      "would + V. «studied» означало бы нереальное условие в настоящем."),
    S(GRAM, "hard",
      "Hardly ___ the station when the train left.",
      "had we reached", ["we had reached", "did we reach", "we reached"],
      "После отрицательных наречий в начале предложения (Hardly, Scarcely, No sooner) нужна инверсия. "
      "Конструкция Hardly … when требует Past Perfect: Hardly had we reached …"),
    S(GRAM, "hard",
      "She is used to ___ up early, so the new timetable doesn't bother her.",
      "getting", ["get", "got", "have got"],
      "be used to + -ing — «иметь привычку, привыкнуть к чему-либо». Не путать с used to + V "
      "(«раньше, бывало»): She used to get up early."),
    S(GRAM, "hard",
      "I'd rather you ___ smoke in here.",
      "didn't", ["don't", "not", "won't"],
      "I'd rather + другое подлежащее + прошедшее время (сослагательное значение): I'd rather you didn't smoke. "
      "Если подлежащее то же самое — инфинитив без to: I'd rather not smoke."),
    S(GRAM, "hard",
      "Don't worry, the report ___ by the time the manager comes back.",
      "will have been finished", ["will finish", "will have finished", "is finishing"],
      "Отчёт сам не заканчивает — нужен пассив. Действие завершится к моменту в будущем (by the time) — "
      "Future Perfect Passive: will have been + V3."),
    S(GRAM, "hard",
      "Neither the teacher nor the students ___ aware of the change in the timetable.",
      "were", ["was", "is", "has been"],
      "В конструкции neither … nor глагол согласуется с ближайшим подлежащим: the students — множественное число, "
      "поэтому were."),
    S(GRAM, "hard",
      "It's high time we ___ home — it's already midnight.",
      "went", ["go", "will go", "have gone"],
      "После It's (high) time + подлежащее используется Past Simple в значении «давно пора»: It's high time we went."),
    S(GRAM, "hard",
      "He denied ___ the window, but everybody knew it was him.",
      "having broken", ["to break", "to have broken", "break"],
      "После deny используется герундий (deny doing / deny having done), а не инфинитив. Перфектный герундий "
      "подчёркивает, что действие было раньше отрицания."),
    S(GRAM, "hard",
      "Not only ___ the exam, but she also got the highest score in the class.",
      "did she pass", ["she passed", "she did pass", "passed she"],
      "Not only в начале предложения требует инверсии, как в вопросе: вспомогательный глагол перед подлежащим — "
      "did she pass."),
    S(GRAM, "hard",
      "You ___ have seen him in Dushanbe yesterday — he was in Paris then.",
      "can't", ["mustn't", "shouldn't", "needn't"],
      "Уверенность в том, что чего-то не было в прошлом: can't/couldn't + have + V3 («не может быть, чтобы ты его "
      "видел»). mustn't have — неправильная форма для этого значения."),
    S(GRAM, "medium",
      "The more you practise, ___ you become.",
      "the more confident", ["more confident", "the most confident", "the confident"],
      "Конструкция «чем …, тем …»: The + сравнительная степень …, the + сравнительная степень … "
      "(The more you practise, the more confident you become)."),
    S(GRAM, "hard",
      "I wish I ___ that to her yesterday. Now she won't talk to me.",
      "hadn't said", ["didn't say", "wouldn't say", "haven't said"],
      "Сожаление о прошлом: I wish + Past Perfect. I wish + Past Simple — сожаление о настоящем."),
    S(GRAM, "hard",
      "She said, \"I will call you tomorrow.\" In reported speech this becomes:",
      "She said she would call me the next day.",
      ["She said she will call me tomorrow.", "She said she would call you tomorrow.",
       "She said she called me the next day."],
      "При согласовании времён will → would, you → me (говорят мне), tomorrow → the next day."),
    S(GRAM, "medium",
      "This is the house ___ my grandfather was born.",
      "where", ["which", "that", "what"],
      "Придаточное обозначает место («в котором») — where = in which. «which»/«that» потребовали бы предлога: "
      "the house which my grandfather was born in."),
    S(GRAM, "medium",
      "Each of the students ___ given a certificate at the end of the course.",
      "was", ["were", "have been", "are being"],
      "Each (of …) требует глагола в единственном числе: Each of the students was given …"),
    # ------------------------------------------------------------------ vocabulary
    S(VOC, "medium",
      "Please ___ this form and hand it to the secretary.",
      "fill in", ["fill on", "fill at", "fill over"],
      "fill in (a form) — «заполнить (анкету, бланк)». В американском варианте также fill out."),
    S(VOC, "medium",
      "Choose the word closest in meaning to \"reluctant\": He was reluctant to answer the question.",
      "unwilling", ["eager", "careless", "polite"],
      "reluctant — «неохотный, делающий что-то нехотя» = unwilling. eager — наоборот, «стремящийся»."),
    S(VOC, "medium",
      "Don't worry if you ___ a mistake — everybody does.",
      "make", ["do", "take", "get"],
      "Устойчивое сочетание make a mistake. С do употребляются homework, exercises, a favour, one's best."),
    S(VOC, "hard",
      "The meeting was put off until Monday. \"Put off\" means",
      "postponed", ["cancelled", "arranged", "moved earlier"],
      "put off — «отложить, перенести на более поздний срок». Отменить — call off или cancel."),
    S(VOC, "medium",
      "Choose the opposite of \"generous\".",
      "mean", ["kind", "wealthy", "brave"],
      "generous — «щедрый», его антоним — mean (или stingy) «скупой». wealthy — «богатый», это не антоним."),
    S(VOC, "hard",
      "The ___ of the new bridge took three years. (CONSTRUCT)",
      "construction", ["constructive", "constructor", "constructed"],
      "После артикля the и перед of нужно существительное со значением процесса — construction (строительство). "
      "constructor — «строитель, конструктор» (лицо), constructive — прилагательное."),
    S(VOC, "hard",
      "The actual price was much higher than we expected. \"Actual\" means",
      "real", ["current", "modern", "topical"],
      "«Ложный друг переводчика»: actual — «фактический, действительный», а не «актуальный» "
      "(актуальный — topical, current)."),
    S(VOC, "medium",
      "My cousin is fluent ___ three languages.",
      "in", ["at", "on", "with"],
      "Устойчивое сочетание fluent in (a language) — «свободно владеющий языком»."),
    S(VOC, "hard",
      "I can't ___ this noise any longer!",
      "put up with", ["put on with", "put off", "put down"],
      "put up with — «терпеть, мириться». put off — «откладывать», put down — «записывать; подавлять»."),
    S(VOC, "medium",
      "Choose the correctly spelled word.",
      "necessary", ["neccessary", "necesary", "neccesary"],
      "Правильно: necessary — одна c и две s (правило-подсказка: one Collar, two Sleeves)."),
    S(VOC, "hard",
      "We were late because there was ___ on the way to the airport.",
      "heavy traffic", ["strong traffic", "big traffic", "thick traffic"],
      "Устойчивое сочетание: heavy traffic — «интенсивное движение, пробки». strong/big traffic не используются."),
    S(VOC, "hard",
      "The lecture was so ___ that half of the audience fell asleep.",
      "boring", ["bored", "boredom", "bore"],
      "Прилагательные на -ing описывают то, что вызывает чувство (boring lecture — скучная лекция), на -ed — "
      "состояние человека (bored students — скучающие студенты)."),
    # ------------------------------------------------------------------ reading: glacier
    S(READ, "hard",
      "What is TRUE about Alexei Fedchenko?",
      "He never saw the glacier that was named after him.",
      ["He mapped the glacier in 1928.", "He built a weather station on the glacier.",
       "He explored the Pamirs in the 1930s."],
      "В тексте: «named after … Alexei Fedchenko, who explored Central Asia in the 1870s, although he never actually "
      "saw the glacier himself». Карту составила экспедиция 1928 года, станцию построили в 1933 году.",
      passage=GLACIER),
    S(READ, "medium",
      "According to the text, the weather station was used to",
      "collect data about the weather and the movement of the ice",
      ["provide electricity for villages", "train mountain climbers", "supply drinking water"],
      "«scientists … measured temperature and snowfall and watched the movement of the ice». Электричество и питьевая "
      "вода упоминаются в связи с реками, а не станцией.",
      passage=GLACIER),
    S(READ, "medium",
      "According to the text, the Fedchenko Glacier has",
      "become shorter and thinner",
      ["grown longer", "stayed the same size", "moved to a lower altitude"],
      "«its lower end has moved back by about a kilometre, and the glacier has become thinner» — ледник "
      "укоротился и стал тоньше.",
      passage=GLACIER),
    S(READ, "hard",
      "Why does the author say \"This matters far beyond the mountains\"?",
      "Because rivers fed by the glaciers are important for many people living downstream.",
      ["Because the glacier can be seen from far away.", "Because tourists come from other countries.",
       "Because scientists from many countries work at the station."],
      "Следующее предложение объясняет: meltwater feeds rivers that millions of people downstream depend on — "
      "от ледников зависит вода для питья, полей и электростанций ниже по течению.",
      passage=GLACIER),
    S(READ, "hard",
      "What may happen in the long term if the glaciers continue to shrink?",
      "There will be less water in the rivers in dry summers.",
      ["There will be more floods every summer.", "The rivers will freeze.",
       "Power stations will produce more electricity."],
      "Автор различает краткосрочный эффект (in the short term — сток может даже вырасти) и долгосрочный "
      "(eventually — much less water … during the dry summer months). Вопрос — о долгосрочном.",
      passage=GLACIER),
    S(READ, "medium",
      "The word \"retreating\" in paragraph 2 is closest in meaning to",
      "moving back", ["advancing", "freezing", "breaking into pieces"],
      "retreat — «отступать». Смысл подтверждает продолжение: its lower end has moved back. "
      "advancing — противоположное значение.",
      passage=GLACIER),
    # ------------------------------------------------------------------ reading: sleep
    S(READ, "hard",
      "What is the main idea of the text?",
      "Sleep plays an active role in learning and memory.",
      ["The brain switches off completely during sleep.", "Afternoon naps are better than night sleep.",
       "Students should study only in the evening."],
      "Главная мысль: сон — не «выключение» мозга, а активный процесс, во время которого закрепляются знания. "
      "Первый неверный вариант — устаревшее мнение, которое автор опровергает.",
      passage=SLEEP),
    S(READ, "medium",
      "In the experiments described, the volunteers who slept",
      "usually remembered more the next day",
      ["forgot all the words", "learnt new skills during the night", "were tested in the evening"],
      "«those who have slept usually remember considerably more». Тестировали обе группы на следующий день.",
      passage=SLEEP),
    S(READ, "hard",
      "What does the text say about afternoon naps?",
      "They can help, but they cannot replace a full night's sleep.",
      ["They are useless.", "They are as good as a full night's sleep.", "They make people forget information."],
      "«even a short afternoon nap can bring some benefit, although it cannot replace a full night's rest».",
      passage=SLEEP),
    S(READ, "hard",
      "According to the author, staying up all night before an exam",
      "often makes the results worse",
      ["is the best way to prepare", "helps to concentrate", "has no effect on memory"],
      "«may feel productive, but it often has the opposite effect» — материал плохо запоминается, уставшему мозгу "
      "труднее сосредоточиться.",
      passage=SLEEP),
    S(READ, "medium",
      "The phrase \"far from true\" (paragraph 1) means",
      "completely wrong", ["partly correct", "well known", "difficult to prove"],
      "far from true — «далеко не так, совершенно неверно». Автор опровергает мнение о сне как пассивном состоянии.",
      passage=SLEEP),
    S(READ, "medium",
      "The word \"lasting\" in the last sentence is closest in meaning to",
      "long-term", ["final", "late", "quick"],
      "lasting knowledge — «прочные, долговременные знания» (от to last — «длиться»). last в значении "
      "«последний» (final) здесь не подходит.",
      passage=SLEEP),
    # ------------------------------------------------------------------ matching
    M(VOC, "hard",
      "Match the adjectives with their definitions.",
      ["reliable", "ambitious", "stubborn", "thrifty"],
      ["refusing to change one's opinion", "easily frightened", "able to be trusted", "careful not to waste money",
       "having a strong desire to succeed"],
      [2, 4, 0, 3],
      "reliable — надёжный; ambitious — честолюбивый; stubborn — упрямый; thrifty — бережливый. "
      "«easily frightened» (timid) — лишнее определение."),
    M(VOC, "medium",
      "Match the phrasal verbs with their meanings.",
      ["give up", "look after", "turn down", "come across"],
      ["find by chance", "stop doing something", "refuse an offer", "take care of", "continue"],
      [1, 3, 2, 0],
      "give up — бросить (привычку, попытки); look after — заботиться; turn down — отклонить (предложение); "
      "come across — случайно найти, наткнуться. «continue» — это carry on / go on."),
    M(GRAM, "hard",
      "Match the beginnings of the sentences with their endings.",
      ["If you heat ice,", "If it rains tomorrow,", "If I were you,", "If she had left earlier,"],
      ["she wouldn't have missed the bus.", "it melts.", "I would apologise.", "we will stay at home.",
       "had stayed at home."],
      [1, 3, 2, 0],
      "Zero conditional (общая истина): If + Present, Present. First (реальное будущее): If + Present, will + V. "
      "Second (нереальное настоящее): If + Past (were), would + V. Third (нереальное прошлое): If + Past Perfect, "
      "would have + V3. «had stayed at home» не подходит ни к одному началу."),
    M(VOC, "medium",
      "Match the formal verbs with their everyday synonyms.",
      ["to purchase", "to assist", "to require", "to obtain"],
      ["to get", "to need", "to sell", "to help", "to buy"],
      [4, 3, 1, 0],
      "purchase = buy; assist = help; require = need; obtain = get. Формальные глаголы часто встречаются "
      "в официальных текстах и объявлениях."),
    M(GRAM, "medium",
      "Match the words with the prepositions that follow them.",
      ["to depend", "to be interested", "to be afraid", "to apologise"],
      ["in", "for", "on", "at", "of"],
      [2, 0, 4, 1],
      "depend on, be interested in, be afraid of, apologise for (something) / to (somebody)."),
    M(GRAM, "hard",
      "Match the sentences with the tenses used in them.",
      ["She has lived here since 2010.", "They were watching TV when I came in.", "By 2030 he will have graduated.",
       "I had finished my work before she arrived."],
      ["Past Continuous", "Present Perfect", "Past Perfect", "Present Perfect Continuous", "Future Perfect"],
      [1, 0, 4, 2],
      "has lived — Present Perfect (с since); were watching — Past Continuous; will have graduated — Future Perfect; "
      "had finished — Past Perfect."),
    M(VOC, "hard",
      "Match the idioms with their meanings.",
      ["a piece of cake", "once in a blue moon", "to break the ice", "to cost an arm and a leg"],
      ["very expensive", "very rarely", "to be very hungry", "very easy",
       "to start a conversation and make people feel relaxed"],
      [3, 1, 4, 0],
      "a piece of cake — «проще простого»; once in a blue moon — «очень редко»; to break the ice — «растопить лёд» "
      "в общении; to cost an arm and a leg — «стоить целое состояние»."),
    M(VOC, "medium",
      "Match the British English words with their American English equivalents.",
      ["flat", "lift", "petrol", "autumn"],
      ["fall", "apartment", "truck", "gas", "elevator"],
      [1, 4, 3, 0],
      "flat — apartment, lift — elevator, petrol — gas (gasoline), autumn — fall. truck — американское "
      "соответствие британского lorry."),
    M(VOC, "medium",
      "Match the words with their opposites.",
      ["ancient", "guilty", "temporary", "rare"],
      ["innocent", "common", "permanent", "modern", "dangerous"],
      [3, 0, 2, 1],
      "ancient — modern (древний — современный), guilty — innocent (виновный — невиновный), temporary — permanent "
      "(временный — постоянный), rare — common (редкий — распространённый)."),
    M(GRAM, "hard",
      "Match the direct speech with the correct reported speech.",
      ["\"I am tired,\" she said.", "\"I have finished,\" he said.", "\"I will help,\" he said.",
       "\"Can you swim?\" she asked me."],
      ["She asked me if I could swim.", "He said he would help.", "She said she was tired.",
       "He said he had finished.", "She asked me could I swim."],
      [2, 3, 1, 0],
      "Сдвиг времён: am → was, have finished → had finished, will → would, can → could. В косвенном общем вопросе "
      "используется if/whether и прямой порядок слов, поэтому «asked me could I swim» неверно."),
]
