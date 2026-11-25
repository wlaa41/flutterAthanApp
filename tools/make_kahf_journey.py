#!/usr/bin/env python3
"""Writes asset/journey/kahf.json, the content of the Al-Kahf Journey.

The journey walks through the whole surah in stops. Each stop tells its part of
the story, then asks about whole ayahs at one of three levels:

  1. English: a question about the ayah, with the ayah shown and heard.
  2. Arabic: the ayah is shown, the player picks its meaning.
  3. Arabic, strong: the meaning is shown, the player picks the ayah.

Nothing of the Quran is typed here. An ayah is named by its number and shown
from the bundled Hafs text; a keepsake names its words by their bare letters
and the script finds them. The meanings are short summaries that follow
al-Tafsir al-Muyassar (King Fahd Complex); the English ones are our own
wording, not a published translation.

  python3 tools/make_kahf_journey.py            # check against the text and write
  python3 tools/make_kahf_journey.py --check    # check only
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TEXT = ROOT / 'asset' / 'quran' / 'hafs.json'
OUT = ROOT / 'asset' / 'journey' / 'kahf.json'

# One line for every ayah, in order: (English, Arabic).
AYAHS = [
    ("Praise be to Allah, who sent down the Book to His servant and put no crookedness in it.",
     'الحمد لله الذي أنزل القرآن على عبده، ولم يجعل فيه ميلًا عن الحق.'),
    ("He made it straight, to warn of a severe punishment from Him and to give the believers who do good the news of a fine reward.",
     'جعله مستقيمًا؛ لينذر بعذاب شديد، ويبشّر المؤمنين العاملين بالصالحات بأجر حسن.'),
    ("They will stay in that reward forever.",
     'يقيمون في ذلك النعيم لا يفارقونه أبدًا.'),
    ("And it warns those who say: Allah has taken a son.",
     'وينذر الذين قالوا: اتخذ الله ولدًا.'),
    ("They have no knowledge of it, nor had their fathers. It is a grave word that leaves their mouths; they speak nothing but a lie.",
     'لا علم لهم بذلك ولا لآبائهم؛ عظُمت مقالتهم، وما يقولون إلا كذبًا.'),
    ("Perhaps you would grieve yourself to death over them if they do not believe in this message.",
     'لعلّك مُهلكٌ نفسك حزنًا عليهم إن لم يؤمنوا بهذا القرآن.'),
    ("We made what is on the earth an adornment for it, to test which of them is best in deeds.",
     'جعلنا ما على الأرض زينةً لها؛ لنختبر الناس أيّهم أحسن عملًا.'),
    ("And We will surely turn what is on it into bare, dry ground.",
     'وسنجعل ما على الأرض ترابًا لا نبات فيه.'),
    ("Do you think the people of the Cave and the Inscription were the only wonder among Our signs?",
     'ليست قصة أصحاب الكهف والرقيم بأعجب آياتنا.'),
    ("The young men took refuge in the cave and said: Our Lord, grant us mercy from Yourself and guide us rightly in our affair.",
     'لجأ الفتية إلى الكهف، ودعوا ربهم أن يرحمهم وييسّر لهم طريق الرشاد.'),
    ("So We made them sleep deeply in the cave for many years.",
     'فأنمناهم في الكهف نومًا عميقًا سنين كثيرة.'),
    ("Then We woke them, to show which of the two groups counted best how long they had stayed.",
     'ثم أيقظناهم؛ ليظهر أيّ الفريقين أضبط لمدة لبثهم.'),
    ("We tell you their story in truth: they were young men who believed in their Lord, and We increased them in guidance.",
     'نقصّ عليك خبرهم بالحق: فتيةٌ آمنوا بربهم، وزدناهم هدى.'),
    ("We made their hearts firm when they stood up and said: Our Lord is the Lord of the heavens and the earth; we will call on no god besides Him.",
     'ثبّتنا قلوبهم حين قاموا وقالوا: ربنا رب السماوات والأرض، لن نعبد غيره.'),
    ("These people of ours have taken gods besides Him. Why do they bring no clear proof? Who does more wrong than one who invents a lie about Allah?",
     'قومنا اتخذوا آلهة من دون الله بلا حجة واضحة، ولا أظلم ممن افترى على الله كذبًا.'),
    ("Since you have left them and what they worship besides Allah, take shelter in the cave; your Lord will spread His mercy for you and ease your affair.",
     'إذ اعتزلتم قومكم وما يعبدون فالجؤوا إلى الكهف؛ ينشر لكم ربكم من رحمته وييسّر أمركم.'),
    ("You would see the sun lean away from their cave as it rose and pass them by as it set, while they lay in its open space. That is one of Allah's signs.",
     'ترى الشمس تميل عن كهفهم إذا طلعت وتتركهم إذا غربت وهم في متّسع منه؛ ذلك من آيات الله.'),
    ("You would think them awake though they slept. We turned them to the right and the left, and their dog stretched its forelegs at the entrance.",
     'تحسبهم أيقاظًا وهم نيام، ونقلّبهم يمينًا وشمالًا، وكلبهم باسطٌ ذراعيه بفِناء الكهف.'),
    ("We woke them so they would ask one another how long they had stayed. Then they sent one of them to the city with their silver coin, to find pure food and to be careful.",
     'أيقظناهم فتساءلوا عن مدة نومهم، ثم بعثوا أحدهم بدراهمهم إلى المدينة ليأتيهم بطعام طيّب متلطّفًا.'),
    ("If they find you out, they will stone you or force you back into their religion, and then you would never succeed.",
     'إن يطّلع قومكم عليكم يرجموكم أو يردّوكم إلى دينهم، فلا تفلحون أبدًا.'),
    ("So We made them known to the people, that they might know Allah's promise is true and the Hour is beyond doubt. Then they argued over them: some said build a structure over them, and those who prevailed said a place of worship.",
     'أطلعنا الناس عليهم ليعلموا أن وعد الله حق وأن الساعة آتية، ثم تنازعوا في أمرهم وما يبنون عليهم.'),
    ("People will guess at their number: three, five or seven, with their dog. Say: my Lord knows their number best. Do not argue about them except briefly.",
     'سيختلف الناس في عددهم رجمًا بالغيب؛ قل: ربي أعلم بعدّتهم، فلا تجادل فيهم إلا جدالًا ظاهرًا.'),
    ("Never say of anything: I will do that tomorrow,",
     'لا تقل لشيء تعزم عليه: سأفعله غدًا.'),
    ("without adding: if Allah wills. Remember your Lord when you forget, and say: may my Lord guide me to what is nearer to right than this.",
     'إلا أن تقول: إن شاء الله، واذكر ربك إذا نسيت، واسأله الهداية لأقرب الرشد.'),
    ("They stayed in their cave three hundred years, and nine more.",
     'لبثوا في كهفهم ثلاثمئة سنة وتسع سنين.'),
    ("Say: Allah knows best how long they stayed. His is the unseen of the heavens and the earth; they have no protector but Him, and He shares His rule with no one.",
     'قل: الله أعلم بمدة لبثهم، له غيب السماوات والأرض، ولا يشرك في حكمه أحدًا.'),
    ("Recite what has been revealed to you of your Lord's Book. No one can change His words, and you will find no refuge except with Him.",
     'اتلُ ما أُوحي إليك من كتاب ربك، لا مبدّل لكلماته، ولن تجد ملجأً سواه.'),
    ("Keep yourself patient with those who call on their Lord morning and evening, seeking His face. Do not look past them for the glitter of this life, and do not obey one whose heart is heedless.",
     'اصبر نفسك مع الذين يدعون ربهم صباحًا ومساءً، ولا تنصرف عنهم لزينة الدنيا، ولا تطع غافل القلب.'),
    ("Say: the truth is from your Lord, so let whoever wills believe and whoever wills disbelieve. We have prepared a Fire for the wrongdoers, and scalding water for their thirst.",
     'قل: الحق من ربكم؛ فمن شاء فليؤمن ومن شاء فليكفر، وللظالمين نار تحيط بهم وماء يشوي الوجوه.'),
    ("Those who believe and do good: We do not let the reward of anyone who does good be lost.",
     'الذين آمنوا وعملوا الصالحات لا نضيع أجر من أحسن منهم عملًا.'),
    ("They will have gardens of Eden with rivers flowing beneath them, bracelets of gold and green garments of silk, reclining on couches. What a fine reward!",
     'لهم جنات إقامة تجري من تحتها الأنهار، يُحلَّون بأساور الذهب ويلبسون الحرير الأخضر متكئين على الأرائك.'),
    ("Tell them the example of two men: to one We gave two gardens of grapevines, ringed with date palms, with crops between them.",
     'اضرب لهم مثل رجلين: لأحدهما حديقتان من أعناب، محاطتان بالنخل، وبينهما زرع.'),
    ("Both gardens gave their fruit in full, and We made a river flow between them.",
     'أثمرت الحديقتان ثمرهما كاملًا، وفجّرنا بينهما نهرًا.'),
    ("He had fruit in plenty, and he said to his companion as they talked: I have more wealth than you and stronger men.",
     'وكان له ثمر كثير، فقال لصاحبه مفتخرًا: أنا أكثر منك مالًا وأعزّ أنصارًا.'),
    ("He entered his garden, wronging himself, and said: I do not think this will ever perish.",
     'دخل حديقته ظالمًا لنفسه وقال: ما أظن أن تهلك هذه أبدًا.'),
    ("And I do not think the Hour will come. Even if I am brought back to my Lord, I will surely find something better than this.",
     'وما أظن القيامة واقعة، ولئن رُجعت إلى ربي لأجدنّ خيرًا من هذه الحديقة.'),
    ("His companion said to him: do you deny the One who created you from dust, then from a drop, then shaped you into a man?",
     'قال له صاحبه المؤمن: أتكفر بالذي خلقك من تراب ثم من نطفة ثم سوّاك رجلًا؟'),
    ("But as for me: He is Allah, my Lord, and I associate no one with my Lord.",
     'أما أنا فأقول: هو الله ربي، ولا أشرك بربي أحدًا.'),
    ("If only, when you entered your garden, you had said: this is what Allah willed; there is no power except through Allah. Though you see me with less wealth and fewer children,",
     'هلّا قلت حين دخلت حديقتك: ما شاء الله، لا قوة إلا بالله، وإن رأيتني أقلّ منك مالًا وولدًا.'),
    ("my Lord may give me better than your garden, and send on yours a calamity from the sky, leaving it bare, slippery ground.",
     'فعسى ربي أن يعطيني خيرًا من حديقتك، ويرسل عليها عذابًا من السماء فتصبح أرضًا ملساء.'),
    ("Or its water may sink deep into the ground, so that you could never reach it.",
     'أو يغور ماؤها في الأرض فلا تقدر على طلبه.'),
    ("His fruit was destroyed, and he began wringing his hands over what he had spent on it, as it lay fallen on its trellises, saying: I wish I had associated no one with my Lord.",
     'أُهلك ثمره فصار يقلّب كفّيه ندمًا على ما أنفق فيها وهي خاوية، ويقول: ليتني لم أشرك بربي أحدًا.'),
    ("He had no group to help him besides Allah, and he could not help himself.",
     'لم تكن له جماعة تنصره من دون الله، وما كان منتصرًا بنفسه.'),
    ("There, protection belongs to Allah, the True. He is best in reward and best in outcome.",
     'هنالك النصرة لله الحق وحده، هو خير ثوابًا وخير عاقبة.'),
    ("Give them the example of this life: it is like rain We send down, and the plants of the earth grow thick with it, then turn to dry stalks the winds scatter.",
     'مثل الحياة الدنيا كماء نزل من السماء فاخضرّ به النبات، ثم صار يابسًا تفرّقه الرياح.'),
    ("Wealth and children are the adornment of this life, but lasting good deeds are better with your Lord in reward and better in hope.",
     'المال والبنون زينة الحياة الدنيا، والأعمال الصالحة الباقية خير ثوابًا وخير أملًا.'),
    ("On the Day We set the mountains moving and you see the earth laid bare, We will gather them and leave none of them behind.",
     'يوم نُزيل الجبال وترى الأرض ظاهرة، ونحشر الناس فلا نترك منهم أحدًا.'),
    ("They will be set before your Lord in rows: you have come to Us as We created you the first time, though you claimed We had set no appointment for you.",
     'يُعرضون على ربك صفًّا: جئتمونا كما خلقناكم أول مرة، وقد زعمتم ألّا موعد لكم.'),
    ("The record will be laid open, and you will see the guilty fearful of what is in it, saying: what a book, that leaves out nothing small or great! And your Lord wrongs no one.",
     'يوضع كتاب الأعمال فيخاف المجرمون مما فيه؛ لا يترك صغيرة ولا كبيرة، ولا يظلم ربك أحدًا.'),
    ("When We told the angels to bow to Adam, they bowed, but not Iblis; he was of the jinn and disobeyed his Lord. Will you take him and his offspring as allies when they are your enemy?",
     'سجد الملائكة لآدم إلا إبليس، كان من الجن فعصى ربه؛ أفتتخذونه وذريته أولياء وهم لكم عدو؟'),
    ("I did not make them witnesses to the creation of the heavens and the earth, nor to their own creation, and I do not take those who mislead as helpers.",
     'ما أشهدتهم خلق السماوات والأرض ولا خلق أنفسهم، وما كنت لأتخذ المضلّين أعوانًا.'),
    ("On the Day He says: call those you claimed were My partners. They will call them, but get no answer, and We will set a pit of ruin between them.",
     'يوم يقول: نادوا شركائي الذين زعمتم، فيدعونهم فلا يستجيبون لهم، وجعلنا بينهم مَهلكًا.'),
    ("The guilty will see the Fire and know they are about to fall into it, and they will find no way to escape it.",
     'يرى المجرمون النار فيوقنون أنهم واقعون فيها، ولا يجدون عنها مهربًا.'),
    ("We have set out every kind of example for people in this Quran, but man is, more than anything, given to argument.",
     'صرّفنا في هذا القرآن للناس من كل مثل، وكان الإنسان أكثر شيء جدلًا.'),
    ("Nothing kept people from believing when guidance came, and from asking their Lord's forgiveness, except waiting for the fate of earlier peoples, or to face the punishment.",
     'ما منع الناس من الإيمان والاستغفار حين جاءهم الهدى إلا طلبهم سنّة الأولين أو معاينة العذاب.'),
    ("We send the messengers only to bring good news and to warn. Yet the disbelievers argue with falsehood to weaken the truth, and they make a mockery of My signs.",
     'ما نرسل الرسل إلا مبشّرين ومنذرين، ويجادل الكافرون بالباطل ليبطلوا الحق ويستهزئون بآياتي.'),
    ("Who does more wrong than one who is reminded of his Lord's signs, then turns away and forgets what his hands have done? Their hearts are covered and their ears are heavy.",
     'لا أظلم ممن ذُكّر بآيات ربه فأعرض عنها ونسي ذنوبه؛ على قلوبهم أغطية وفي آذانهم صمم.'),
    ("Your Lord is the Forgiving, full of mercy. If He took them to task for what they earned, He would hasten their punishment; but they have an appointed time they cannot escape.",
     'ربك الغفور ذو الرحمة؛ لو آخذهم بذنوبهم لعجّل لهم العذاب، لكن لهم موعدًا لا مفرّ منه.'),
    ("Those towns: We destroyed them when they did wrong, and We set an appointed time for their destruction.",
     'تلك القرى أهلكناها لمّا ظلمت، وجعلنا لهلاكها موعدًا.'),
    ("Musa said to his young servant: I will not stop until I reach the meeting of the two seas, even if I travel for ages.",
     'قال موسى لفتاه: لا أزال أسير حتى أبلغ ملتقى البحرين ولو سرت زمنًا طويلًا.'),
    ("When they reached the place where the two seas meet, they forgot their fish, and it made its way into the sea.",
     'فلما بلغا ملتقى البحرين نسيا حوتهما، فاتخذ طريقه في البحر.'),
    ("When they had gone on, he said to his servant: bring us our meal; this journey has worn us out.",
     'فلما جاوزا المكان قال موسى لفتاه: أحضر غداءنا، لقد تعبنا من سفرنا هذا.'),
    ("He said: remember when we rested at the rock? I forgot the fish, and only Satan made me forget to mention it. It took its way into the sea, a wonder.",
     'قال فتاه: نسيت الحوت عند الصخرة، وما أنسانيه إلا الشيطان، وقد اتخذ طريقه في البحر عجبًا.'),
    ("Musa said: that is what we were looking for. So they went back, retracing their steps.",
     'قال موسى: ذلك ما كنا نطلبه، فرجعا يتتبعان آثارهما.'),
    ("There they found one of Our servants, to whom We had given mercy from Us and taught knowledge from Our own.",
     'فوجدا عبدًا من عبادنا آتيناه رحمة وعلّمناه من عندنا علمًا.'),
    ("Musa said to him: may I follow you, so that you teach me some of the right guidance you were taught?",
     'قال له موسى: هل أتبعك لتعلّمني مما عُلّمت رشدًا؟'),
    ("He said: you will not be able to be patient with me.",
     'قال: إنك لن تستطيع الصبر على صحبتي.'),
    ("How could you be patient with something you have no full knowledge of?",
     'وكيف تصبر على أمر لا تعلم حقيقته؟'),
    ("Musa said: you will find me patient, if Allah wills, and I will not disobey you in anything.",
     'قال موسى: ستجدني إن شاء الله صابرًا، ولا أخالف لك أمرًا.'),
    ("He said: if you follow me, then ask me about nothing until I mention it to you myself.",
     'قال: إن صحبتني فلا تسألني عن شيء حتى أبيّنه لك.'),
    ("They set off, and when they boarded a ship he made a hole in it. Musa said: did you hole it to drown its people? You have done a dreadful thing.",
     'ركبا السفينة فخرقها الخضر، فقال موسى: أخرقتها لتغرق أهلها؟ لقد فعلت أمرًا منكرًا.'),
    ("He said: did I not say that you would not be able to be patient with me?",
     'قال الخضر: ألم أقل إنك لن تستطيع معي صبرًا؟'),
    ("Musa said: do not hold me to account for forgetting, and do not make my task with you hard.",
     'قال موسى: لا تؤاخذني بنسياني، ولا تشقّ عليّ في صحبتك.'),
    ("They went on until they met a boy, and he killed him. Musa said: have you killed an innocent soul who had killed no one? You have done a terrible thing.",
     'لقيا غلامًا فقتله الخضر، فقال موسى: أقتلت نفسًا بريئة بغير نفس؟ لقد فعلت أمرًا فظيعًا.'),
    ("He said: did I not tell you that you would not be able to be patient with me?",
     'قال الخضر: ألم أقل لك إنك لن تستطيع معي صبرًا؟'),
    ("Musa said: if I ask you about anything after this, keep me with you no longer; you have had excuse enough from me.",
     'قال موسى: إن سألتك عن شيء بعدها فلا تصاحبني، فقد بلغتَ العذر مني.'),
    ("They came to the people of a town and asked them for food, but they refused to host them. There they found a wall about to fall, and he set it straight. Musa said: you could have taken payment for that.",
     'استطعما أهل قرية فأبوا ضيافتهما، فوجدا جدارًا يكاد يسقط فأقامه الخضر، فقال موسى: لو شئت لأخذت عليه أجرًا.'),
    ("He said: this is the parting between you and me. I will tell you the meaning of what you could not bear patiently.",
     'قال: هذا فراق بيني وبينك، سأخبرك بتأويل ما لم تصبر عليه.'),
    ("The ship belonged to poor people who worked at sea. I wanted to damage it, because a king was coming who seized every sound ship by force.",
     'أما السفينة فكانت لمساكين يعملون في البحر، فعِبتُها لأن وراءهم ملكًا يأخذ كل سفينة صالحة غصبًا.'),
    ("The boy: his parents were believers, and we feared he would burden them with rebellion and disbelief.",
     'وأما الغلام فكان أبواه مؤمنين، فخشينا أن يحملهما على الطغيان والكفر.'),
    ("So we wished their Lord to give them in his place one better in purity and closer in mercy.",
     'فأردنا أن يبدلهما ربهما ولدًا خيرًا منه صلاحًا وأقرب رحمة.'),
    ("The wall belonged to two orphan boys in the town. Under it was a treasure of theirs, and their father had been righteous, so your Lord willed them to grow up and bring out their treasure. I did none of it of my own accord.",
     'وأما الجدار فكان ليتيمين تحته كنز لهما وكان أبوهما صالحًا، فأراد ربك أن يكبرا ويستخرجاه، وما فعلته عن أمري.'),
    ("They ask you about Dhul-Qarnayn. Say: I will recite to you something of his story.",
     'يسألونك عن ذي القرنين؛ قل: سأتلو عليكم من خبره ذكرًا.'),
    ("We established him in the land and gave him a way to everything.",
     'مكّنّا له في الأرض وآتيناه من كل شيء سببًا يبلغ به مراده.'),
    ("So he followed a way.",
     'فسلك طريقًا مما آتيناه.'),
    ("When he reached the setting of the sun, he found it setting in a dark, muddy spring, and found a people near it. We said: Dhul-Qarnayn, you may punish them or treat them well.",
     'بلغ مغرب الشمس فرآها كأنها تغرب في عين حمئة، ووجد عندها قومًا، فخُيّر بين تعذيبهم والإحسان إليهم.'),
    ("He said: whoever does wrong, we will punish him; then he will be returned to his Lord, who will punish him terribly.",
     'قال: من ظلم فسنعذّبه، ثم يُردّ إلى ربه فيعذّبه عذابًا شديدًا.'),
    ("But whoever believes and does good will have the best reward, and we will speak to him gently of our command.",
     'وأما من آمن وعمل صالحًا فله الجزاء الحسن، وسنقول له قولًا ميسّرًا.'),
    ("Then he followed another way.",
     'ثم سلك طريقًا آخر.'),
    ("When he reached the rising of the sun, he found it rising on a people for whom We had made no shelter from it.",
     'بلغ مطلع الشمس فوجدها تطلع على قوم لا ساتر لهم منها.'),
    ("So it was. And We knew fully all that he had with him.",
     'كذلك، وقد أحاط علمنا بكل ما عنده.'),
    ("Then he followed another way.",
     'ثم سلك طريقًا آخر.'),
    ("When he reached a place between two mountains, he found beside them a people who could hardly understand a word.",
     'بلغ ما بين الجبلين فوجد عندهما قومًا لا يكادون يفهمون كلامًا.'),
    ("They said: Dhul-Qarnayn, Yajuj and Majuj spread corruption in the land. Shall we pay you to build a barrier between us and them?",
     'قالوا: إن يأجوج ومأجوج مفسدون في الأرض، فهل نجعل لك أجرًا لتبني بيننا وبينهم سدًّا؟'),
    ("He said: what my Lord has given me is better. Help me with your strength, and I will build a strong barrier between you and them.",
     'قال: ما مكّنني فيه ربي خير من مالكم، فأعينوني بقوتكم أجعل بينكم وبينهم حاجزًا.'),
    ("Bring me blocks of iron. When he had filled the gap between the two mountainsides, he said: blow. When he had made it like fire, he said: bring me molten copper to pour over it.",
     'آتوني قطع الحديد، فلما ملأ ما بين الجبلين قال: انفخوا، حتى صار نارًا فصبّ عليه النحاس المذاب.'),
    ("So they could not climb over it, and they could not break through it.",
     'فما استطاعوا أن يصعدوا فوقه، وما استطاعوا أن ينقبوه.'),
    ("He said: this is a mercy from my Lord. But when my Lord's promise comes, He will level it to the ground, and my Lord's promise is true.",
     'قال: هذا رحمة من ربي، فإذا جاء وعد ربي جعله مستويًا بالأرض، ووعد ربي حق.'),
    ("On that day We will leave them surging against one another like waves. The Horn will be blown, and We will gather them all together.",
     'يومئذ يموج بعضهم في بعض، ويُنفخ في الصور فنجمع الخلق جميعًا.'),
    ("On that Day We will show Hell plainly to the disbelievers,",
     'ونُبرز جهنم يومئذ للكافرين عيانًا.'),
    ("those whose eyes were veiled from My reminder, and who could not bear to hear.",
     'الذين كانت أعينهم في غطاء عن ذكري، وكانوا لا يطيقون سماع الحق.'),
    ("Do the disbelievers think they can take My servants as protectors instead of Me? We have prepared Hell as a lodging for the disbelievers.",
     'أيظن الكافرون أن يتخذوا عبادي أولياء من دوني؟ إنا أعددنا جهنم للكافرين منزلًا.'),
    ("Say: shall we tell you who are the greatest losers in their deeds?",
     'قل: هل نخبركم بأخسر الناس أعمالًا؟'),
    ("Those whose effort is lost in this life, while they think they are doing good.",
     'الذين ضاع سعيهم في الدنيا وهم يظنون أنهم يحسنون العمل.'),
    ("They are the ones who denied their Lord's signs and the meeting with Him. Their deeds have come to nothing, and We will give them no weight on the Day of Rising.",
     'أولئك الذين كفروا بآيات ربهم ولقائه فبطلت أعمالهم، فلا نقيم لهم يوم القيامة وزنًا.'),
    ("That is their repayment: Hell, because they disbelieved and mocked My signs and My messengers.",
     'ذلك جزاؤهم جهنم بما كفروا واستهزؤوا بآياتي ورسلي.'),
    ("Those who believe and do good will have the Gardens of Firdaws as their lodging,",
     'الذين آمنوا وعملوا الصالحات لهم جنات الفردوس منزلًا.'),
    ("staying there forever, with no wish to leave.",
     'خالدين فيها، لا يريدون عنها تحوّلًا.'),
    ("Say: if the sea were ink for the words of my Lord, the sea would run dry before the words of my Lord ran out, even if We brought another sea like it to help.",
     'قل: لو كان البحر حبرًا لكلمات ربي لنفد البحر قبل أن تنفد، ولو جئنا بمثله مددًا.'),
    ("Say: I am only a human being like you; it is revealed to me that your God is One God. So whoever hopes to meet his Lord, let him do good deeds and associate no one in the worship of his Lord.",
     'قل: إنما أنا بشر مثلكم يوحى إليّ أن إلهكم إله واحد؛ فمن رجا لقاء ربه فليعمل صالحًا ولا يشرك بعبادته أحدًا.'),
]

# Ayahs the Arabic levels never ask about or offer as a choice: three are the
# same short line ("then he followed a way"), two repeat ayah 67 almost word
# for word. They are still read, heard and recited.
SKIP = {72, 75, 85, 89, 92}

# (id, kind, English, Arabic, art, keepsake, stops)
# keepsake: (id, English, Arabic, ayah, first bare word, last bare word, English line)
# stop: (English, Arabic, first, last, [story, English], [story, Arabic],
#        [(ayah, question, answer, wrong, wrong)])
SECTIONS = [
    ('opening', 'bridge', "The Opening", 'مطلع السورة', 'book', None, [
        ("The straight Book", 'الكتاب القيّم', 1, 5,
         ["The surah opens with praise: Allah sent down the Book to His servant, with nothing crooked in it.",
          "It is straight. It warns of a severe punishment, brings good news to believers who do good, and warns those who say Allah has taken a son."],
         ['تبدأ السورة بحمد الله الذي أنزل الكتاب على عبده، ولم يجعل فيه عوجًا.',
          'هو كتاب مستقيم: ينذر بعذاب شديد، ويبشّر المؤمنين الذين يعملون الصالحات، وينذر الذين قالوا اتخذ الله ولدًا.'],
         [(1, "What does the surah begin with?", "Praise of Allah, who sent down the Book", "A promise of victory in battle", "The story of the first man"),
          (2, "What good news does the Book bring?", "A fine reward for believers who do good", "Long life for everyone who reads it", "Wealth for those who memorise it"),
          (4, "Whom does this ayah warn?", "Those who say Allah has taken a son", "Those who travel far from home", "Those who sleep through the night"),
          (5, "What does the ayah say about that claim?", "They have no knowledge of it; it is a lie", "Their fathers had proof of it", "It was written in the Book")]),
        ("What adorns the earth", 'زينة الأرض', 6, 8,
         ["The Prophet, peace be upon him, grieved deeply for those who would not believe. Allah tells him not to wear himself out with sorrow over them.",
          "Everything on the earth is an adornment and a test: who does best? And all of it will end as bare ground."],
         ['حزن النبي صلى الله عليه وسلم حزنًا شديدًا على من لم يؤمن، فنهاه الله أن يُهلك نفسه أسفًا عليهم.',
          'كل ما على الأرض زينة واختبار: أيّ الناس أحسن عملًا؟ ثم يصير كله ترابًا لا نبات فيه.'],
         [(6, "Why was the Prophet, peace be upon him, so grieved?", "Because his people would not believe", "Because he had lost his wealth", "Because the journey was long"),
          (7, "Why was the earth adorned?", "To test who is best in deeds", "So people would never leave it", "To hide what lies beneath it"),
          (8, "What will become of everything on the earth?", "Bare, dry ground", "Gardens that never fade", "A sea without a shore")]),
    ]),
    ('cave', 'story', "The Cave", 'أصحاب الكهف', 'cave',
     ('coin', "the silver coin", 'الدرهم الفضي', 19, 'فابعثوا', 'المدينة',
      "So send one of you to the city with this silver coin of yours."), [
        ("Into the cave", 'إلى الكهف', 9, 12,
         ["A group of young men took shelter in a cave and called on their Lord: grant us mercy from Yourself, and set our affair right.",
          "Allah let them sleep there for many years, then woke them. Their story is one of His signs."],
         ['لجأ فتيةٌ إلى كهف ودعوا ربهم أن يؤتيهم من عنده رحمة، وأن ييسّر لهم أمرهم على الرشاد.',
          'فأنامهم الله فيه سنين كثيرة ثم أيقظهم، وقصتهم آية من آياته.'],
         [(9, "Who is this story about?", "The people of the Cave", "The builders of a great city", "Travellers lost at sea"),
          (10, "What did the young men ask for in the cave?", "Mercy from their Lord, and right guidance", "Food and water for a long stay", "Victory over their people"),
          (11, "What happened to them in the cave?", "Allah made them sleep for many years", "They dug a tunnel to escape", "They wrote down their story"),
          (12, "What came after their long sleep?", "Allah woke them", "Their people forgave them", "The cave was closed forever")]),
        ("Standing firm", 'الثبات على الحق', 13, 16,
         ["They were young men who believed in their Lord, and He gave them more guidance and made their hearts firm.",
          "They stood and said: our Lord is the Lord of the heavens and the earth. Leaving what their people worshipped, they made for the cave, trusting in His mercy."],
         ['كانوا فتية آمنوا بربهم، فزادهم الله هدى وثبّت قلوبهم.',
          'قاموا فقالوا: ربنا رب السماوات والأرض. واعتزلوا ما يعبد قومهم ولجؤوا إلى الكهف راجين رحمة ربهم.'],
         [(13, "What did Allah give the young men who believed?", "More guidance", "A hidden treasure", "An army to defend them"),
          (14, "What did they declare when they stood up?", "Our Lord is the Lord of the heavens and the earth", "We will rule this city", "We will leave at sunrise"),
          (15, "What did they say their people lacked?", "Any clear proof for their gods", "Enough food for the winter", "A wise king to lead them"),
          (16, "Where were they told to take shelter?", "In the cave", "In the king's palace", "In a far-off city")]),
        ("Asleep, yet guarded", 'نيام في حفظ الله', 17, 18,
         ["Inside the cave they slept in an open space. The rising sun leaned away from them and the setting sun passed them by.",
          "Anyone looking would have thought them awake. Allah turned them to the right and the left, and their dog lay stretched at the entrance."],
         ['ناموا في متّسعٍ من الكهف؛ تميل عنهم الشمس إذا طلعت وتتركهم إذا غربت.',
          'من رآهم حسبهم أيقاظًا. يقلّبهم الله يمينًا وشمالًا، وكلبهم باسطٌ ذراعيه عند المدخل.'],
         [(17, "What did the sun do as it rose over their cave?", "It leaned away from them", "It shone straight on their faces", "It stopped in the sky"),
          (17, "What does the ayah call this?", "One of the signs of Allah", "A trick of the eye", "A custom of that land"),
          (18, "What would someone seeing them have thought?", "That they were awake", "That they were statues", "That the cave was empty"),
          (18, "Where was their dog?", "Stretched out at the entrance", "Asleep beside the king", "Lost in the city")]),
        ("Awake", 'اليقظة', 19, 20,
         ["Allah woke them, and they asked each other how long they had slept. A day, or part of a day, some said. Your Lord knows best, said others.",
          "They sent one of them to the city with a silver coin to buy pure food, carefully, so that no one would notice him."],
         ['أيقظهم الله فتساءلوا عن مدة نومهم؛ فظنّ بعضهم أنها يوم أو بعض يوم، وردّ آخرون علمها إلى الله.',
          'ثم بعثوا أحدهم إلى المدينة بدراهم من الفضة ليشتري طعامًا طيّبًا، وليتلطّف حتى لا يشعر بهم أحد.'],
         [(19, "How long did they first think they had slept?", "A day, or part of a day", "Seven full years", "A single hour"),
          (19, "What did they send one of them to the city with?", "Their silver coin", "A letter for the king", "A sword and a shield"),
          (19, "What was he to bring back?", "Pure, good food", "News of their families", "Water from the river"),
          (20, "What did they fear if their people found them?", "Being stoned or forced back to their religion", "Being sent to another land", "Being made to work in the fields")]),
        ("Found", 'العثور عليهم', 21, 22,
         ["Allah let the people find them, so they would know His promise is true and the Hour is certain.",
          "Later people argued over how many they were: three, five, seven. Say: my Lord knows their number best."],
         ['أطلع الله الناس عليهم؛ ليعلموا أن وعده حق وأن الساعة لا شك فيها.',
          'ثم اختلف الناس في عددهم: ثلاثة أو خمسة أو سبعة. والجواب: ربي أعلم بعددهم.'],
         [(21, "Why did Allah let the people find them?", "So they would know His promise is true", "So the city could take their coin", "So the young men could be punished"),
          (21, "What did the people argue about putting over them?", "A structure, or a place of worship", "A market for travellers", "A wall around the city"),
          (22, "What do people guess about?", "How many they were", "The name of their city", "The colour of their dog"),
          (22, "What is the right answer to give?", "My Lord knows their number best", "They were surely nine", "No one may ever speak of them")]),
        ("If Allah wills", 'إن شاء الله', 23, 26,
         ["A lesson comes with the story: never say you will do something tomorrow without adding, if Allah wills. And remember your Lord when you forget.",
          "They stayed in the cave three hundred years and nine more. Allah knows best how long; the unseen belongs to Him."],
         ['مع القصة أدب: لا تقل لشيء إنك فاعله غدًا حتى تقول: إن شاء الله، واذكر ربك إذا نسيت.',
          'ولبثوا في كهفهم ثلاثمئة سنة وتسع سنين. والله أعلم بمدة لبثهم، له غيب السماوات والأرض.'],
         [(23, "What should you not say about tomorrow?", "I will do that tomorrow, without adding: if Allah wills", "Tomorrow will be a hard day", "Tomorrow I will rest"),
          (24, "What should you do when you forget?", "Remember your Lord", "Blame the one beside you", "Give up what you intended"),
          (25, "How long did they stay in the cave?", "Three hundred years and nine more", "Forty years", "Seven nights"),
          (26, "Who knows best how long they stayed?", "Allah", "The people of the city", "The one sent to buy food")]),
    ]),
    ('book', 'bridge', "Stay with the Book", 'اتلُ واصبر', 'book', None, [
        ("Patience with the faithful", 'اصبر نفسك', 27, 31,
         ["Recite the Book of your Lord; no one can change His words. And stay patiently with those who call on Him morning and evening.",
          "The truth has come: believe or refuse. A Fire waits for the wrongdoers; for those who believe and do good, gardens with rivers flowing beneath them."],
         ['اتلُ كتاب ربك فلا مبدّل لكلماته، واصبر نفسك مع الذين يدعونه صباحًا ومساءً.',
          'جاء الحق من الله: فمن شاء آمن ومن شاء كفر. للظالمين نار، وللذين آمنوا وعملوا الصالحات جنات تجري من تحتها الأنهار.'],
         [(27, "What is said about the words of Allah?", "No one can change them", "Only kings may read them", "They are kept in a cave"),
          (28, "Whom should you stay patiently with?", "Those who call on their Lord morning and evening", "Those with the most wealth", "Those who travel the farthest"),
          (29, "Where does the truth come from?", "From your Lord", "From the elders of the city", "From whoever speaks loudest"),
          (31, "What is promised to those who believe and do good?", "Gardens with rivers flowing beneath them", "A kingdom on earth", "A long life without work")]),
    ]),
    ('gardens', 'story', "The Two Gardens", 'صاحب الجنتين', 'gardens',
     ('vine', "the vine", 'عنقود العنب', 32, 'جعلنا', 'بنخل',
      "We gave one of them two gardens of grapevines, and ringed them with date palms."), [
        ("Two gardens, one boast", 'الجنتان', 32, 36,
         ["A man was given two gardens of grapevines, ringed with date palms, with crops between and a river running through. Both gave their fruit in full.",
          "He boasted to his companion: I have more wealth and more men than you. He walked into his garden and said: this will never perish, and I do not think the Hour will come."],
         ['رجل أُعطي حديقتين من أعناب، يحيط بهما النخل، وبينهما زرع ونهر، وقد أثمرتا ثمرًا كاملًا.',
          'ففاخر صاحبه بكثرة ماله ورجاله، ودخل حديقته وهو يظن أنها لن تهلك أبدًا وأن الساعة لن تقوم.'],
         [(32, "What grew in the two gardens?", "Grapevines, with date palms around them", "Only thorns and wild grass", "Olive trees on a hill"),
          (34, "What did the owner boast of?", "More wealth and stronger men", "More knowledge of the Book", "More years of travel"),
          (35, "What did he say on entering his garden?", "I do not think this will ever perish", "All of this is from my Lord", "I will give half of it away"),
          (36, "What did he think about the Hour?", "That it would never come", "That it was very near", "That only he would be saved")]),
        ("A friend's reminder", 'موعظة الصاحب', 37, 41,
         ["His companion answered: do you deny the One who made you from dust? He is Allah, my Lord, and I set no one beside Him.",
          "If only you had said: this is what Allah willed; there is no power except through Allah. He may give me better than your garden, and send ruin on yours."],
         ['أجابه صاحبه المؤمن: أتكفر بمن خلقك من تراب؟ أما أنا فالله ربي ولا أشرك به أحدًا.',
          'وذكّره أن يقول إذا دخل حديقته: ما شاء الله، لا قوة إلا بالله؛ فقد يعطيه ربه خيرًا منها، ويرسل عليها ما يهلكها.'],
         [(37, "What did his companion remind him of?", "That Allah created him from dust", "That his father planted the garden", "That the river belonged to the king"),
          (38, "What did the companion say of himself?", "Allah is my Lord; I associate no one with Him", "I will soon own a garden like yours", "I have no need of anyone's advice"),
          (39, "What should the owner have said in his garden?", "This is what Allah willed; there is no power except through Allah", "This is the work of my own hands", "No one may enter here but me"),
          (41, "What might happen to the garden's water?", "It could sink deep into the ground", "It could turn to wine", "It could flood the city")]),
        ("All of it gone", 'ذهاب النعمة', 42, 44,
         ["Then it happened. His fruit was destroyed, and he stood wringing his hands over all he had spent, the garden fallen on its trellises.",
          "I wish I had set no one beside my Lord, he said. He had no one to help him. Real protection belongs to Allah alone."],
         ['ثم وقع ما حُذّر منه: هلك ثمره، فصار يقلّب كفّيه ندمًا على ما أنفق فيها وقد سقطت على عروشها.',
          'وتمنّى لو لم يشرك بربه أحدًا، ولم يجد من ينصره؛ فالنصرة الحقة لله وحده.'],
         [(42, "What happened to his fruit?", "It was all destroyed", "It was sold at a high price", "It ripened twice that year"),
          (42, "What did he say when he saw the ruin?", "I wish I had associated no one with my Lord", "I will plant it again tomorrow", "My companion has done this to me"),
          (43, "Who came to help him?", "No one; he could not even help himself", "His sons and his servants", "The people of the next town"),
          (44, "To whom does protection belong?", "To Allah, the True", "To the one with the most wealth", "To the strongest tribe")]),
    ]),
    ('world', 'bridge', "This World and the Day", 'الدنيا والآخرة', 'rain', None, [
        ("Like rain on the earth", 'مثل الحياة الدنيا', 45, 49,
         ["This life is like rain: plants grow thick with it, then dry into stalks the wind scatters. Wealth and children adorn it, but lasting good deeds are better.",
          "A Day is coming when the mountains move and everyone is gathered. The record of deeds is laid open, leaving out nothing small or great."],
         ['الدنيا كماء المطر: ينبت به الزرع ثم ييبس فتفرّقه الرياح. المال والبنون زينتها، والأعمال الصالحة الباقية خير.',
          'ويأتي يوم تزول فيه الجبال ويُحشر الناس جميعًا، ويوضع كتاب الأعمال لا يترك صغيرة ولا كبيرة.'],
         [(45, "What is the life of this world compared to?", "Rain that makes plants grow, then they dry and scatter", "A mountain that never moves", "A river that always runs full"),
          (46, "What is better with your Lord than wealth and children?", "Lasting good deeds", "A famous name", "A strong house"),
          (47, "What happens to the mountains on that Day?", "They are set moving", "They grow taller", "They turn to gold"),
          (49, "What does the record of deeds leave out?", "Nothing, small or great", "Whatever was done in secret", "The deeds of the young")]),
        ("The old enemy", 'عداوة إبليس', 50, 53,
         ["When the angels were told to bow to Adam, they bowed. Iblis did not. He was of the jinn, and he disobeyed his Lord.",
          "Would you take him and his offspring as allies, when they are your enemy? On that Day those once called on will not answer."],
         ['أُمر الملائكة بالسجود لآدم فسجدوا إلا إبليس؛ كان من الجن فخرج عن طاعة ربه.',
          'فكيف يُتخذ هو وذريته أولياء وهم أعداء؟ ويوم القيامة لا يستجيب الشركاء لمن دعاهم.'],
         [(50, "Who refused to bow to Adam?", "Iblis", "One of the angels", "A king of that time"),
          (50, "What was Iblis?", "One of the jinn", "One of the angels", "One of the sons of Adam"),
          (52, "What happens when they call their so-called partners?", "They get no answer", "They are carried to safety", "They are given a second life"),
          (53, "What do the guilty realise when they see the Fire?", "That they are about to fall into it", "That it is far away", "That it will soon go out")]),
        ("Every kind of example", 'من كل مثل', 54, 59,
         ["The Quran sets out every kind of example for people, yet man argues more than anything. Messengers come only to bring good news and to warn.",
          "Your Lord is forgiving and full of mercy. He does not rush to punish, but there is an appointed time no one escapes."],
         ['بيّن الله في القرآن للناس من كل مثل، والإنسان أكثر شيء جدلًا. وما يُرسَل الرسل إلا مبشّرين ومنذرين.',
          'وربك الغفور ذو الرحمة لا يعاجل بالعقوبة، ولكن لهم موعد لا مهرب منه.'],
         [(54, "What is man most given to?", "Argument", "Silence", "Gratitude"),
          (56, "Why are the messengers sent?", "To bring good news and to warn", "To collect wealth", "To rule over cities"),
          (58, "How is your Lord described here?", "The Forgiving, full of mercy", "Quick to punish every fault", "Far from His servants"),
          (59, "Why were those towns destroyed?", "Because they did wrong", "Because they grew too large", "Because of a great flood")]),
    ]),
    ('khidr', 'story', "Musa and Al-Khidr", 'موسى والخضر', 'sea',
     ('ship', "the ship", 'السفينة', 79, 'اما', 'البحر',
      "As for the ship, it belonged to poor people who worked at sea."), [
        ("Where the two seas meet", 'مجمع البحرين', 60, 64,
         ["Musa set out with his young servant, saying he would not stop until he reached the place where the two seas meet.",
          "At a rock there, their fish slipped away into the sea, and the servant forgot to say so. When Musa heard, he said: that is the place we were looking for. They turned back."],
         ['خرج موسى مع فتاه عازمًا ألّا يتوقف حتى يبلغ ملتقى البحرين.',
          'وعند صخرة هناك انسلّ حوتهما إلى البحر ونسي الفتى أن يخبره. فلما علم موسى عرف أنه المكان المطلوب، فرجعا على آثارهما.'],
         [(60, "Where did Musa want to reach?", "The place where the two seas meet", "The top of a high mountain", "The gates of a great city"),
          (61, "What did they forget at that place?", "Their fish", "Their staff", "Their water"),
          (63, "Whom did the servant blame for his forgetting?", "Satan", "Musa", "The sea"),
          (64, "What did Musa say when he heard about the fish?", "That is what we were looking for", "We must find other food", "We have lost our way")]),
        ("A servant given knowledge", 'عبدٌ آتاه الله علمًا', 65, 70,
         ["There they found a servant of Allah, given mercy and taught knowledge from Him. Musa asked: may I follow you, so that you teach me?",
          "You will not have the patience, he said. Musa promised to be patient, if Allah willed. Then ask me about nothing, he said, until I speak of it myself."],
         ['وجدا عبدًا من عباد الله آتاه رحمة وعلّمه من عنده علمًا، فاستأذنه موسى أن يتبعه ليتعلم منه.',
          'فأخبره أنه لن يستطيع الصبر معه. ووعد موسى بالصبر إن شاء الله، فشرط عليه ألّا يسأله عن شيء حتى يحدّثه عنه.'],
         [(65, "What had Allah given this servant?", "Mercy, and knowledge from Himself", "A kingdom and an army", "A ship and a crew"),
          (66, "What did Musa ask of him?", "To follow him and learn from him", "To carry his message to a king", "To show him the way home"),
          (67, "What did he say Musa would lack?", "Patience", "Strength", "Food for the road"),
          (70, "What condition did he set?", "Ask me about nothing until I mention it", "Walk behind me in silence all day", "Tell no one my name")]),
        ("The ship", 'السفينة', 71, 73,
         ["They boarded a ship, and he made a hole in it. Musa could not hold back: did you do that to drown its people?",
          "Did I not say you would not have the patience? Musa asked him to excuse his forgetting and not to be hard on him."],
         ['ركبا في السفينة فخرقها، فلم يصبر موسى وأنكر عليه: أتريد أن تُغرق أهلها؟',
          'فذكّره بأنه لن يستطيع الصبر معه، فاعتذر موسى بالنسيان وسأله ألّا يشقّ عليه.'],
         [(71, "What did he do to the ship?", "He made a hole in it", "He bought it from its owners", "He sailed it out to sea alone"),
          (71, "What did Musa fear would happen?", "That its people would drown", "That the king would be angry", "That they would be late"),
          (72, "What did he remind Musa of?", "That he had said Musa would not be patient", "That the ship was his own", "That the sea was calm"),
          (73, "What did Musa ask?", "Not to be blamed for forgetting", "To be given the ship", "To go back to the rock")]),
        ("The boy", 'الغلام', 74, 76,
         ["They went on and met a boy, and he killed him. Musa cried out: have you killed an innocent soul? That is a terrible thing.",
          "Again he was reminded. Musa said: if I ask you about anything after this, keep me with you no longer."],
         ['ثم انطلقا فلقيا غلامًا فقتله، فأنكر موسى قتل نفس بريئة وعدّه أمرًا فظيعًا.',
          'فذكّره مرة أخرى، فقال موسى: إن سألتك عن شيء بعدها فلا تصاحبني.'],
         [(74, "Whom did they meet next?", "A boy", "An old king", "A group of fishermen"),
          (74, "What did Musa call the boy?", "An innocent soul", "A known thief", "A lost traveller"),
          (75, "What was Musa reminded of again?", "That he would not be able to be patient", "That the journey was nearly over", "That the boy was his kin"),
          (76, "What did Musa say should happen if he asked again?", "He should no longer be kept as a companion", "He would pay a fine in silver", "He would walk ahead alone")]),
        ("The wall", 'الجدار', 77, 78,
         ["They came to a town and asked its people for food, but were refused. There stood a wall about to fall, and he set it straight.",
          "Musa said: you could have asked payment for that. This is where we part, he answered. Now I will tell you the meaning of what you could not bear."],
         ['أتيا أهل قرية فطلبا منهم طعامًا فأبوا أن يضيّفوهما، ووجدا فيها جدارًا يوشك أن يسقط فأقامه.',
          'فقال موسى: لو شئت لأخذت عليه أجرًا. قال: هذا فراق بيني وبينك، وسأخبرك بتأويل ما لم تصبر عليه.'],
         [(77, "How did the people of the town treat them?", "They refused to host them", "They gave them a feast", "They asked them to stay a year"),
          (77, "What did he do with the leaning wall?", "He set it straight", "He pulled it down", "He painted it white"),
          (77, "What did Musa suggest?", "Taking payment for the work", "Leaving before nightfall", "Building a second wall"),
          (78, "What did he say then?", "This is the parting between you and me", "Let us rest here tonight", "You have passed the test")]),
        ("What it all meant", 'التأويل', 79, 82,
         ["The ship belonged to poor people, and a king was seizing every sound ship. The boy's parents were believers, and Allah would give them a better child.",
          "Under the wall lay a treasure for two orphans whose father had been righteous. I did none of it of my own accord, he said."],
         ['كانت السفينة لمساكين، ووراءهم ملك يأخذ كل سفينة صالحة غصبًا. وكان أبوا الغلام مؤمنين، فأراد الله أن يبدلهما خيرًا منه.',
          'وتحت الجدار كنز ليتيمين كان أبوهما صالحًا. وبيّن أنه لم يفعل شيئًا من ذلك من تلقاء نفسه.'],
         [(79, "Whose ship was it?", "Poor people who worked at sea", "A rich merchant from the city", "The king's own sailors"),
          (79, "Why was the ship damaged?", "A king was seizing every sound ship", "It was too old to sail", "Its owners had asked for it"),
          (80, "What is said about the boy's parents?", "They were believers", "They were rulers of the town", "They had left him long ago"),
          (82, "What lay under the wall?", "A treasure belonging to two orphans", "A well of sweet water", "The grave of a king")]),
    ]),
    ('qarnayn', 'story', "Dhul-Qarnayn", 'ذو القرنين', 'wall',
     ('iron', "the iron", 'قطعة الحديد', 96, 'ءاتوني', 'الحديد',
      "Bring me blocks of iron."), [
        ("To the setting sun", 'مغرب الشمس', 83, 88,
         ["Dhul-Qarnayn was given power in the land and a way to everything. He travelled until he reached the setting of the sun and found a people there.",
          "He said: whoever does wrong will be punished, and whoever believes and does good will have the best reward and a gentle word."],
         ['مكّن الله لذي القرنين في الأرض وآتاه من كل شيء سببًا، فسار حتى بلغ مغرب الشمس ووجد عندها قومًا.',
          'فحكم بأن من ظلم يُعذَّب، وأن من آمن وعمل صالحًا فله الجزاء الحسن والقول الليّن.'],
         [(83, "Whom do they ask about?", "Dhul-Qarnayn", "The people of the Cave", "The owner of the two gardens"),
          (84, "What was he given?", "Power in the land and a way to everything", "A ship that never sank", "A garden with a river"),
          (86, "Where did his first journey take him?", "To the setting of the sun", "To the bottom of the sea", "To a city of gold"),
          (88, "What did he promise whoever believes and does good?", "The best reward and a gentle word", "A share of his army", "Freedom from all work")]),
        ("To the rising sun", 'مطلع الشمس', 89, 91,
         ["Then he took another way, until he reached the rising of the sun.",
          "He found it rising on a people with no shelter from it. And Allah knew fully all that he had with him."],
         ['ثم سلك طريقًا آخر حتى بلغ مطلع الشمس.',
          'فوجدها تطلع على قوم ليس لهم ما يسترهم منها. وقد أحاط الله علمًا بكل ما عنده.'],
         [(90, "Where did his second journey take him?", "To the rising of the sun", "Back to his own city", "To the meeting of two seas"),
          (90, "What did the people there lack?", "Any shelter from the sun", "Any water to drink", "Any animals to ride"),
          (91, "What does Allah say of all that he had?", "We knew it fully", "It was soon lost", "It was given to another")]),
        ("Between two mountains", 'بين السدّين', 92, 95,
         ["A third way brought him between two mountains, to a people who could hardly understand speech.",
          "They asked him to build a barrier against Yajuj and Majuj, and offered to pay. What my Lord has given me is better, he said. Help me with your strength."],
         ['ثم سار حتى بلغ ما بين الجبلين، فوجد قومًا لا يكادون يفهمون كلامًا.',
          'فسألوه أن يبني بينهم وبين يأجوج ومأجوج سدًّا مقابل أجر، فأخبرهم أن ما أعطاه ربه خير، وطلب عونهم بقوتهم.'],
         [(93, "Where did his third journey take him?", "Between two mountains", "To an island in the sea", "To the cave of the sleepers"),
          (94, "Whom did the people complain of?", "Yajuj and Majuj", "The king who seized ships", "The owner of the two gardens"),
          (94, "What did they ask him to build?", "A barrier between them", "A city with high towers", "A road through the mountains"),
          (95, "How did he answer their offer of payment?", "What my Lord has given me is better", "Double it and I will begin", "Pay me when the work is done")]),
        ("Iron and copper", 'زُبَر الحديد', 96, 98,
         ["He called for blocks of iron and filled the gap between the mountainsides. Blow, he said, until it glowed like fire, then poured molten copper over it.",
          "They could neither climb it nor break through. This is a mercy from my Lord, he said. When His promise comes, He will level it."],
         ['طلب قطع الحديد حتى ملأ ما بين الجبلين، ثم أمرهم بالنفخ حتى صار كالنار، فصبّ عليه النحاس المذاب.',
          'فلم يقدروا أن يصعدوه ولا أن ينقبوه. وقال: هذا رحمة من ربي، فإذا جاء وعده سوّاه بالأرض.'],
         [(96, "What did he build the barrier from?", "Blocks of iron, with molten copper poured over", "Stone and river clay", "Palm trunks and rope"),
          (97, "What could they not do to the barrier?", "Climb over it or break through it", "See it from far away", "Walk along beside it"),
          (98, "What did he call the barrier?", "A mercy from my Lord", "The work of my own hands", "A gift to my people"),
          (98, "What will happen when his Lord's promise comes?", "He will level it to the ground", "It will grow higher", "It will turn to gold")]),
    ]),
    ('closing', 'bridge', "The Closing", 'خاتمة السورة', 'sea', None, [
        ("That Day", 'يوم يُنفخ في الصور', 99, 102,
         ["On that Day they will surge like waves against one another. The Horn is blown, and all are gathered.",
          "Hell is shown plainly to those whose eyes were veiled from Allah's reminder and who could not bear to listen."],
         ['يومئذ يموج الناس بعضهم في بعض، ويُنفخ في الصور فيُجمع الخلق جميعًا.',
          'وتُعرض جهنم على الذين كانت أعينهم في غطاء عن ذكر الله وكانوا لا يطيقون سماع الحق.'],
         [(99, "What is blown on that Day?", "The Horn", "A wind from the east", "A fire across the sea"),
          (100, "What is shown plainly to the disbelievers?", "Hell", "The barrier of iron", "The two gardens"),
          (101, "What had covered their eyes?", "A veil from Allah's reminder", "The dust of travel", "The dark of the cave"),
          (102, "What do they wrongly think they can do?", "Take Allah's servants as protectors instead of Him", "Hide in the mountains", "Buy their way out")]),
        ("The greatest losers", 'الأخسرون أعمالًا', 103, 106,
         ["Shall we tell you who loses most in their deeds? Those whose effort in this life is wasted while they think they are doing well.",
          "They denied the signs of their Lord and the meeting with Him, so their deeds count for nothing."],
         ['من أخسر الناس أعمالًا؟ الذين ضاع سعيهم في الدنيا وهم يظنون أنهم يحسنون.',
          'كفروا بآيات ربهم ولقائه، فبطلت أعمالهم فلا وزن لها يوم القيامة.'],
         [(103, "Whom does this passage describe?", "The greatest losers in their deeds", "The richest of all people", "The first to reach the cave"),
          (104, "What do they think of their own work?", "That they are doing good", "That it is worthless", "That no one sees it"),
          (105, "What did they deny?", "Their Lord's signs and the meeting with Him", "The length of the journey", "The price of the food"),
          (106, "What did they make of Allah's signs and messengers?", "A mockery", "A song", "A law for the city")]),
        ("The words of my Lord", 'كلمات ربي', 107, 110,
         ["Those who believe and do good will have the Gardens of Firdaws, and will never wish to leave.",
          "If the sea were ink for the words of my Lord, it would run dry first. Say: I am only human like you; your God is One. Do good, and worship Him alone."],
         ['للذين آمنوا وعملوا الصالحات جنات الفردوس، لا يريدون التحوّل عنها.',
          'ولو كان البحر حبرًا لكلمات الله لنفد قبل أن تنفد. والنبي بشر يوحى إليه أن الإله واحد؛ فمن رجا لقاء ربه عمل صالحًا ولم يشرك به أحدًا.'],
         [(107, "What will believers who do good have?", "The Gardens of Firdaws", "The two gardens of the boaster", "A palace by the sea"),
          (108, "Will they wish to leave?", "No, never", "Yes, after a time", "Only to visit their old home"),
          (109, "What would run out first?", "The sea, if it were ink", "The words of my Lord", "The pens of the writers"),
          (110, "What should one who hopes to meet his Lord do?", "Do good and worship Him alone", "Travel to the two seas", "Wait in a cave")]),
    ]),
]

# WORDS-BEGIN
# The harder words, for the optional "meanings of the words" in level 2:
# (ayah, word, how many words, their bare letters, meaning).
WORDS = [
    (1, 10, 1, 'عوجا', 'ميلًا عن الحق'),
    (2, 0, 1, 'قيما', 'مستقيمًا لا اختلاف فيه'),
    (2, 2, 2, 'باسا شديدا', 'عذابًا شديدًا'),
    (2, 4, 2, 'من لدنه', 'من عنده'),
    (5, 7, 2, 'كبرت كلمة', 'عظُمت في القبح مقالتُهم'),
    (6, 1, 2, 'بخع نفسك', 'مُهلكٌ نفسَك حزنًا'),
    (6, 10, 1, 'اسفا', 'حزنًا شديدًا'),
    (7, 7, 1, 'لنبلوهم', 'لنختبرهم'),
    (8, 4, 2, 'صعيدا جرزا', 'ترابًا لا نبات فيه'),
    (9, 4, 1, 'الكهف', 'الغار الواسع في الجبل'),
    (9, 5, 1, 'والرقيم', 'اللوح المكتوب فيه أسماؤهم'),
    (10, 1, 1, 'اوى', 'لجأ والتجأ'),
    (10, 15, 1, 'رشدا', 'هدايةً وصوابًا'),
    (11, 0, 3, 'فضربنا على ءاذانهم', 'أنمناهم نومًا عميقًا'),
    (12, 1, 1, 'بعثنهم', 'أيقظناهم من نومهم'),
    (12, 8, 1, 'امدا', 'مدّةً من الزمن'),
    (14, 0, 3, 'وربطنا على قلوبهم', 'قوّينا قلوبهم وثبّتناها'),
    (14, 18, 1, 'شططا', 'قولًا جائرًا بعيدًا عن الحق'),
    (15, 9, 2, 'بسلطن بين', 'بحجةٍ واضحة'),
    (16, 18, 1, 'مرفقا', 'ما ترتفقون وتنتفعون به'),
    (17, 4, 1, 'تزور', 'تميل وتعدل'),
    (17, 11, 1, 'تقرضهم', 'تتركهم وتعدل عنهم'),
    (17, 16, 1, 'فجوة', 'مُتّسعٍ من الكهف'),
    (17, 32, 2, 'وليا مرشدا', 'ناصرًا يهديه إلى الحق'),
    (18, 1, 1, 'ايقاظا', 'منتبهين مستيقظين'),
    (18, 3, 1, 'رقود', 'نيام'),
    (18, 12, 1, 'بالوصيد', 'بفِناء الكهف ومدخله'),
    (18, 21, 1, 'رعبا', 'فزعًا وخوفًا'),
    (19, 22, 1, 'بورقكم', 'بدراهمكم من الفضة'),
    (19, 28, 2, 'ازكى طعاما', 'أحلّ وأطيب طعامًا'),
    (19, 33, 1, 'وليتلطف', 'وليترفّق ويتخفَّ حتى لا يُكشف أمرهم'),
    (20, 2, 2, 'يظهروا عليكم', 'يطّلعوا عليكم ويعرفوا مكانكم'),
    (21, 1, 2, 'اعثرنا عليهم', 'أطلعنا الناس عليهم'),
    (22, 8, 2, 'رجما بالغيب', 'قولًا بالظن من غير دليل'),
    (22, 22, 2, 'فلا تمار', 'فلا تجادل'),
    (22, 29, 1, 'تستفت', 'تسأل'),
    (25, 0, 1, 'ولبثوا', 'ومكثوا وأقاموا'),
    (26, 9, 3, 'ابصر به واسمع', 'تعجّبٌ: ما أبصرَه وما أسمعَه!'),
    (27, 14, 1, 'ملتحدا', 'ملجأً تلجأ إليه'),
    (28, 0, 2, 'واصبر نفسك', 'احبِس نفسك وثبّتها معهم'),
    (28, 6, 2, 'بالغدوة والعشي', 'أولَ النهار وآخرَه'),
    (28, 10, 4, 'ولا تعد عيناك عنهم', 'لا تصرف نظرك عنهم إلى غيرهم'),
    (28, 29, 1, 'فرطا', 'ضياعًا وهلاكًا'),
    (29, 16, 1, 'سرادقها', 'سورها المحيط بها'),
    (29, 21, 1, 'كالمهل', 'كالزيت العكِر شديد الحرارة'),
    (29, 26, 2, 'وساءت مرتفقا', 'قبُحت منزلًا ومقامًا'),
    (31, 2, 2, 'جنت عدن', 'جناتُ إقامةٍ دائمة'),
    (31, 18, 1, 'سندس', 'رقيق الحرير'),
    (31, 19, 1, 'واستبرق', 'غليظ الحرير'),
    (31, 23, 1, 'الارائك', 'الأسِرّة المزيّنة بالستائر'),
    (32, 9, 2, 'وحففنهما بنخل', 'وأحطناهما بالنخل'),
    (33, 2, 2, 'ءاتت اكلها', 'أعطت ثمرها'),
    (33, 4, 4, 'ولم تظلم منه شيا', 'ولم تُنقص من ثمرها شيئًا'),
    (33, 9, 1, 'خللهما', 'وسطَهما وبينَهما'),
    (34, 6, 1, 'يحاوره', 'يراجعه في الكلام'),
    (34, 11, 2, 'واعز نفرا', 'وأقوى أنصارًا وأعوانًا'),
    (35, 9, 1, 'تبيد', 'تهلك وتفنى'),
    (36, 11, 1, 'منقلبا', 'مرجِعًا وعاقبة'),
    (37, 14, 2, 'سوىك رجلا', 'جعلك إنسانًا معتدل الخَلق'),
    (40, 9, 1, 'حسبانا', 'عذابًا من السماء'),
    (40, 13, 2, 'صعيدا زلقا', 'أرضًا ملساء لا يثبت عليها قدم'),
    (41, 3, 1, 'غورا', 'غائرًا ذاهبًا في الأرض'),
    (42, 0, 2, 'واحيط بثمره', 'أُهلكت ثماره وأمواله كلها'),
    (42, 3, 2, 'يقلب كفيه', 'يقلّبهما ندمًا وتحسّرًا'),
    (42, 10, 3, 'خاوية على عروشها', 'ساقطةٌ قد تهدّم بعضها على بعض'),
    (43, 3, 1, 'فئة', 'جماعة'),
    (43, 10, 1, 'منتصرا', 'ممتنعًا بقوته من عذاب الله'),
    (44, 8, 1, 'عقبا', 'عاقبة'),
    (45, 14, 1, 'هشيما', 'يابسًا متكسّرًا'),
    (45, 15, 2, 'تذروه الريح', 'تُفرّقه الرياح وتنسفه'),
    (46, 5, 2, 'والبقيت الصلحت', 'الأعمال الصالحة يبقى ثوابها'),
    (47, 5, 1, 'بارزة', 'ظاهرةً لا يسترها شيء'),
    (47, 8, 1, 'نغادر', 'نترك'),
    (49, 4, 1, 'مشفقين', 'خائفين'),
    (49, 8, 1, 'يويلتنا', 'يا هلاكَنا!'),
    (49, 18, 1, 'احصىها', 'أثبتها وعدّها'),
    (50, 11, 4, 'ففسق عن امر ربه', 'خرج عن طاعة ربه'),
    (51, 12, 1, 'عضدا', 'أعوانًا وأنصارًا'),
    (52, 12, 1, 'موبقا', 'مَهلِكًا يهلكون فيه'),
    (53, 5, 1, 'مواقعوها', 'داخلوها واقعون فيها'),
    (53, 9, 1, 'مصرفا', 'مَعدِلًا ينصرفون إليه'),
    (54, 1, 1, 'صرفنا', 'بيّنّا ونوّعنا'),
    (54, 13, 1, 'جدلا', 'خصومةً ومنازعة'),
    (55, 18, 1, 'قبلا', 'عِيانًا ومقابلة'),
    (56, 10, 1, 'ليدحضوا', 'ليُبطلوا ويُزيلوا'),
    (56, 17, 1, 'هزوا', 'سخريةً واستهزاءً'),
    (57, 16, 1, 'اكنة', 'أغطية'),
    (57, 21, 1, 'وقرا', 'صممًا وثِقلًا'),
    (58, 18, 1, 'موئلا', 'ملجأً ومنجى'),
    (59, 6, 2, 'لمهلكهم موعدا', 'وقتًا معلومًا لهلاكهم'),
    (60, 3, 1, 'لفتىه', 'لخادمه الذي يصحبه'),
    (60, 4, 2, 'لا ابرح', 'لا أزال أسير'),
    (60, 8, 2, 'مجمع البحرين', 'ملتقى البحرين'),
    (60, 12, 1, 'حقبا', 'زمنًا طويلًا'),
    (61, 10, 1, 'سربا', 'مسلكًا وطريقًا'),
    (62, 11, 1, 'نصبا', 'تعبًا ومشقة'),
    (64, 4, 1, 'نبغ', 'نطلب'),
    (64, 8, 1, 'قصصا', 'يتتبّعان آثار أقدامهما'),
    (68, 7, 1, 'خبرا', 'علمًا ومعرفة'),
    (70, 8, 4, 'احدث لك منه ذكرا', 'أبدأ أنا ببيانه لك'),
    (71, 14, 1, 'امرا', 'أمرًا منكرًا عظيمًا'),
    (73, 5, 5, 'ولا ترهقني من امري عسرا', 'ولا تكلّفني مشقة'),
    (74, 9, 1, 'زكية', 'طاهرةً لم تُذنب'),
    (74, 15, 1, 'نكرا', 'منكرًا فظيعًا'),
    (76, 12, 1, 'عذرا', 'حدَّ الإعذار فلا لوم عليك'),
    (77, 6, 2, 'استطعما اهلها', 'طلبا منهم طعامًا'),
    (77, 10, 1, 'يضيفوهما', 'يُنزلوهما ضيفين ويطعموهما'),
    (77, 16, 1, 'ينقض', 'يسقط وينهدم'),
    (77, 17, 1, 'فاقامه', 'فعدّله وأصلح ميله'),
    (78, 6, 1, 'بتاويل', 'بتفسيرِ وبيانِ حقيقة'),
    (79, 9, 1, 'اعيبها', 'أجعلها معيبة'),
    (79, 16, 1, 'غصبا', 'قهرًا بغير حق'),
    (80, 7, 3, 'يرهقهما طغينا وكفرا', 'يحملهما على الطغيان والكفر'),
    (81, 6, 1, 'زكوة', 'صلاحًا وطهارة'),
    (81, 8, 1, 'رحما', 'برًّا بوالديه ورحمة'),
    (82, 18, 1, 'اشدهما', 'قوّتهما وكمال عقلهما'),
    (84, 1, 2, 'مكنا له', 'أعطيناه مُلكًا وسلطانًا'),
    (84, 9, 1, 'سببا', 'طريقًا يوصله إلى ما يريد'),
    (85, 0, 2, 'فاتبع سببا', 'فسلك طريقًا'),
    (86, 8, 2, 'عين حمئة', 'عينِ ماءٍ ذاتِ طينٍ أسود'),
    (90, 14, 1, 'سترا', 'ما يسترهم من الشمس'),
    (93, 4, 1, 'السدين', 'الجبلين'),
    (93, 9, 4, 'لا يكادون يفقهون قولا', 'لا يقاربون فهم كلام غيرهم'),
    (94, 12, 1, 'خرجا', 'أجرًا ومالًا'),
    (95, 11, 1, 'ردما', 'حاجزًا حصينًا'),
    (96, 1, 2, 'زبر الحديد', 'قِطَعَ الحديد'),
    (96, 7, 1, 'الصدفين', 'جانبَي الجبلين'),
    (96, 18, 1, 'قطرا', 'نحاسًا مُذابًا'),
    (97, 3, 1, 'يظهروه', 'يعلوه ويصعدوا فوقه'),
    (97, 7, 1, 'نقبا', 'خرقًا وثقبًا'),
    (98, 10, 1, 'دكاء', 'مستويًا بالأرض'),
    (99, 3, 3, 'يموج في بعض', 'يختلط بعضهم ببعض'),
    (99, 8, 1, 'الصور', 'القَرن الذي يُنفخ فيه'),
    (100, 4, 1, 'عرضا', 'إظهارًا وإبرازًا'),
    (101, 4, 1, 'غطاء', 'غِشاوةٍ وستر'),
    (102, 10, 1, 'اعتدنا', 'أعددنا وهيّأنا'),
    (102, 13, 1, 'نزلا', 'منزلًا مُعدًّا لهم'),
    (104, 1, 2, 'ضل سعيهم', 'بطل عملهم وضاع'),
    (105, 6, 1, 'فحبطت', 'فبطلت'),
    (105, 13, 1, 'وزنا', 'قدرًا وقيمة'),
    (107, 8, 1, 'الفردوس', 'أعلى الجنة وأوسطها'),
    (108, 5, 1, 'حولا', 'تحوّلًا وانتقالًا'),
    (109, 4, 1, 'مدادا', 'حبرًا يُكتب به'),
    (109, 7, 1, 'لنفد', 'لفَنِيَ وانتهى'),
    (109, 17, 1, 'مددا', 'زيادةً وعونًا'),
    (110, 13, 3, 'يرجوا لقاء ربه', 'يطمع في ثواب ربه يوم يلقاه'),
]
# WORDS-END


def letters(text):
    """Bare letters: no marks, one alif. Same rule as journeyLetters in Dart."""
    out = []
    for ch in text:
        c = ord(ch)
        if 0x064B <= c <= 0x065F or c == 0x0670 or 0x06D6 <= c <= 0x06ED or 0x08D3 <= c <= 0x08FF:
            continue
        if c in (0x0640, 0x00A0):
            continue
        if c in (0x0671, 0x0623, 0x0625, 0x0622):
            out.append('ا')
            continue
        out.append(ch)
    return ''.join(out)


def build():
    kahf = json.loads(TEXT.read_text(encoding='utf-8'))['surahs'][17]
    problems = []

    def bare(ayah):
        return [letters(w) for w in kahf[ayah - 1][0].split(' ')]

    def text_ok(value, arabic):
        if not value or value != value.strip() or '—' in value or '–' in value or '  ' in value:
            return False
        has_arabic = any('؀' <= ch <= 'ۿ' for ch in value)
        return has_arabic if arabic else not has_arabic

    if len(AYAHS) != len(kahf):
        problems.append(f'{len(AYAHS)} meanings for {len(kahf)} ayahs')
    for number, (en, ar) in enumerate(AYAHS, start=1):
        if not text_ok(en, False) or not text_ok(ar, True):
            problems.append(f'ayah {number}: check its meanings')
    for kind, values in (('English', [a[0] for a in AYAHS]), ('Arabic', [a[1] for a in AYAHS])):
        seen = {}
        for number, value in enumerate(values, start=1):
            if value in seen and not {number, seen[value]} <= SKIP:
                problems.append(f'ayahs {seen[value]} and {number} share one {kind} meaning')
            seen[value] = number

    sections = []
    expected = 1
    stories = 0
    for sid, kind, en, ar, art, keepsake, stops in SECTIONS:
        section = {'id': sid, 'kind': kind, 'en': en, 'ar': ar, 'art': art, 'stops': []}
        if kind == 'story':
            stories += 1
            section['number'] = stories
        if (kind == 'story') != (keepsake is not None):
            problems.append(f'{sid}: a story has a keepsake, a bridge has none')
        if keepsake:
            kid, ken, kar, ayah, first, last, line = keepsake
            words = bare(ayah)
            a = words.index(letters(first)) if letters(first) in words else -1
            b = max((i for i, w in enumerate(words) if w.startswith(letters(last))), default=-1)
            if a < 0 or b < a:
                problems.append(f'{sid}: keepsake words not found in ayah {ayah}')
            section['keepsake'] = {'id': kid, 'en': ken, 'ar': kar, 'ayah': ayah, 'first': a, 'last': b, 'line': line}
        for index, (sen, sar, first, last, story_en, story_ar, questions) in enumerate(stops, start=1):
            stop_id = f'{sid}-{index}'
            if first != expected or last < first:
                problems.append(f'{stop_id}: starts at {first}, expected {expected}')
            expected = last + 1
            for value, arabic in [(sen, False), (sar, True)] + [(p, False) for p in story_en] + [(p, True) for p in story_ar]:
                if not text_ok(value, arabic):
                    problems.append(f'{stop_id}: check "{value[:40]}"')
            if len(story_en) != 2 or len(story_ar) != 2:
                problems.append(f'{stop_id}: a story is two short paragraphs in each language')
            if not 3 <= len(questions) <= 4:
                problems.append(f'{stop_id}: three or four questions')
            asked = []
            for ayah, question, answer, wrong1, wrong2 in questions:
                if not first <= ayah <= last:
                    problems.append(f'{stop_id}: question on ayah {ayah} lies outside {first}-{last}')
                options = [answer, wrong1, wrong2]
                if len(set(options)) != 3 or not all(text_ok(v, False) for v in options + [question]):
                    problems.append(f'{stop_id}: check the question "{question}"')
                if not question.endswith('?'):
                    problems.append(f'{stop_id}: "{question}" is not a question')
                asked.append({'ayah': ayah, 'q': question, 'a': answer, 'w': [wrong1, wrong2]})
            if len({q['q'] for q in asked}) != len(asked):
                problems.append(f'{stop_id}: the same question twice')
            section['stops'].append({
                'id': stop_id, 'en': sen, 'ar': sar, 'first': first, 'last': last,
                'storyEn': story_en, 'storyAr': story_ar, 'questions': asked,
            })
        sections.append(section)
    if expected != len(kahf) + 1:
        problems.append(f'the stops end at ayah {expected - 1}')
    if stories != 4:
        problems.append(f'{stories} stories, expected 4')

    words = {}
    for verse, word, span, expected_letters, meaning in WORDS:
        got = ' '.join(bare(verse)[word:word + span])
        if got != expected_letters:
            problems.append(f'{verse}:{word}+{span} reads "{got}", not "{expected_letters}"')
        words.setdefault(str(verse), []).append({'word': word, 'span': span, 'meaning': meaning})

    data = {
        'surah': 18,
        'sections': sections,
        'ayahs': [{'en': en, 'ar': ar, **({'skip': True} if number in SKIP else {})}
                  for number, (en, ar) in enumerate(AYAHS, start=1)],
        'words': words,
    }
    return data, problems


if __name__ == '__main__':
    data, problems = build()
    for problem in problems:
        print(problem)
    if problems:
        sys.exit(1)
    stops = sum(len(s['stops']) for s in data['sections'])
    questions = sum(len(stop['questions']) for s in data['sections'] for stop in s['stops'])
    print(f'{len(data["ayahs"])} ayahs, {stops} stops, {questions} English questions, '
          f'{sum(len(v) for v in data["words"].values())} word meanings: all match the Hafs text.')
    if '--check' not in sys.argv:
        OUT.parent.mkdir(parents=True, exist_ok=True)
        OUT.write_text(json.dumps(data, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
        print(f'Wrote {OUT.relative_to(ROOT)}')
