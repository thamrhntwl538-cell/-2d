extends RefCounted
## Stable bilingual identifiers. Journals retain note IDs rather than translated text.

const ROOMS := {
 1:["بهو الصفحة الأولى","The First Page"], 2:["ممر الواجبات","Assignment Hall"],
 3:["مختبر المخطوطات","Ink Laboratory"], 4:["ركن الشعلة السوداء","Black Flame Alcove"],
 5:["الهوامش المحذوفة","Erased Margins"], 6:["الأرشيف المطوي","Folded Archive"],
 7:["غرفة الإدخال","INPUT Chamber"], 8:["قاعة الترتيب","PROCESS Hall"],
 9:["جسر الإخراج","OUTPUT Bridge"], 10:["قاعة الأثقال","Balance Hall"],
 11:["مدرجات المحاضرة الصامتة","The Silent Lecture"], 12:["مشغل التجليد","The Bindery"],
 13:["رواق المصحّح","Corrector's Walk"], 14:["قاعة المحاكمة","Compiler Tribunal"],
 15:["الصفحة التالية","The Next Page"]
}

const WORDS := {
 "game_title":["المحاضرة الأخيرة","LAST LECTURE"],
 "world_title":["المكتبة المتحوّلة","THE FOLDING LIBRARY"],
 "environment_build":["M17 · تجربة البيئة","M17 · Environment build"],
 "controls":["A / D  حركة     SPACE  قفز     E  تفاعل     M  خريطة     N  يوميات     ESC  إيقاف","A / D  Move     SPACE  Jump     E  Interact     M  Map     N  Journal     ESC  Pause"],
 "interact":["E  ·  %s","E  ·  %s"], "continue":["متابعة","Continue"],
 "close":["إغلاق","Close"], "cancel":["الرجوع","Back"], "map":["الخريطة","Map"],
 "journal":["اليوميات","Journal"], "pause":["استراحة","Pause"],
 "resume":["متابعة الرحلة","Continue exploring"], "restart":["رحلة جديدة","New journey"],
 "restart_title":["بدء رحلة جديدة؟","Begin a new journey?"],
 "restart_body":["سيُحذف تقدم هذه التجربة ويعود البطل إلى بهو الصفحة الأولى.","This resets this build's progress and returns you to the First Page."],
 "restart_confirm":["بدء الرحلة من جديد","Start again"],
 "language":["اللغة","Language"], "ar":["العربية","العربية"], "en":["English","English"],
 "unknown_room":["مسار غير مستكشف","Uncharted passage"],
 "current_location":["موضعك الحالي","Your location"], "visited":["مكتشف","Visited"],
 "map_legend":["ذهبي: موضعك  ·  أزرق: مكتشف  ·  سماوي متقطع: اختصار مفتوح","Gold: you  ·  Blue: explored  ·  Cyan dash: open shortcut"],
 "map_hint":["تُكتشف المسارات بالمشي؛ الخريطة لا تنقلك بين المناطق.","Paths are discovered by exploring. The map does not teleport you."],
 "journal_empty":["لم تقرأ شهادة بعد. تحتفظ اليوميات بما تجده، حتى بعد مغادرة المكتبة.","No testimony read yet. Your journal keeps what you find, even after leaving the library."],
 "journal_hint":["الشهادات محفوظة بهويتها؛ يمكنك تبديل اللغة دون فقد موضع القراءة.","Testimonies retain their identity when you change language."],
 "read":["قراءة","Read"], "next":["التالي","Next"], "previous":["السابق","Previous"],
 "dialogue_title":["صاحب الشعلة السوداء","The Black Flame"],
 "hero_speaker":["البطل","Warden"], "stranger_speaker":["الغريب","Stranger"],
 "ink_title":["شبكة الحبر","The Ink Network"],
 "ink_instruction":["أدر القنوات الثلاث لتصل الحبر من المصدر إلى آلة الطي. شاهد اتجاه كل وصلة.","Turn the three channels to lead ink from the source to the folding machine. Follow each connection."],
 "ink_clue":["المصدر يسار القناة A؛ آلة الطي فوق القناة C.","The source is west of A. The folding machine is north of C."],
 "rotate":["تدوير %s","Turn %s"], "confirm":["تجربة الآلية","Test mechanism"],
 "process_title":["طاولة الترتيب","The Ordering Table"],
 "process_instruction":["الكتب الثلاثة على طاولة واحدة. طابق الخانات المرقمة مع الدليل القريب.","All three books share this table. Match the numbered slots to the nearby diagram."],
 "process_clue":["دليل الخانات:  1: △   |   2: □   |   3: ○","Slot diagram:  1: △   |   2: □   |   3: ○"],
 "slot":["الخانة %s","Slot %s"], "set_order":["تثبيت الترتيب","Confirm order"],
 "balance_title":["ميزان التجليد","The Binding Balance"],
 "balance_instruction":["انقل أثقال الكتب بين الكفتين حتى يستقر الجسر عند العلامة. الحمل الداكن مثبت في اليسار.","Move the book weights between the pans until the bridge meets its mark. The dark weight is fixed on the left."],
 "balance_clue":["سماكة الكتب تبين وزنها؛ شاهد ميل الجسر بعد كل نقل.","Book thickness shows weight. Watch the bridge tilt after each move."],
 "weight":["الثقل %s","Weight %s"], "left":["يسار","Left"], "right":["يمين","Right"],
 "balance_confirm":["تثبيت الجسر","Settle bridge"],
 "overlay_title":["صفحتان من شهادة واحدة","Two Pages, One Testimony"],
 "overlay_instruction":["حرّك الصفحتين الشفافتين حتى تتطابق علامات الطية ويكتمل الرسم.","Shift the two translucent pages until their fold marks align and the drawing becomes whole."],
 "overlay_clue":["العلامة الذهبية هي موضع محاذاة الصفحتين.","The gold mark shows where the two pages align."],
 "page":["الصفحة %s","Page %s"],
 "pop_title":["الكتاب المجسّم","The Pop-up Book"],
 "pop_instruction":["غيّر طيات الكتاب بحسب الرسم الظاهر، ثم افتح الحجرة الجانبية.","Change the book's folds to match the visible diagram, then open the side chamber."],
 "pop_clue":["مخطط الطي:  1: نصف طية  |  2: قائمة  |  3: نصف طية","Fold diagram:  1: half-fold  |  2: upright  |  3: half-fold"],
 "fold":["الطية %s","Fold %s"], "fold_state_0":["مسطحة","Flat"],
 "fold_state_1":["نصف طية","Half-fold"], "fold_state_2":["قائمة","Upright"],
 "output_title":["نشر درج الصفحات","Unfold the Page Stair"],
 "output_instruction":["الكتب مرتبة في قاعة PROCESS. فعّل النشر من هذه الأرض الثابتة، وانتظر استقرار الصفحة.","The books remain arranged in PROCESS. Deploy the page from this fixed ground and wait for it to settle."],
 "deploy":["نشر الصفحة","Deploy page"],
 "safe_controls":["الخطأ بلا ضرر أو خسارة كتب · الحل محفوظ بعد الاستقرار","Wrong answers cost nothing · Settled solutions are remembered"],
 "exit_title":["عتبة المحاضرة التالية","The Next Lecture"],
 "exit_warning":["بعد العبور يُغلق العالم الأول، ولن تستطيع العودة إلى المكتبة. يمكنك البقاء الآن لإكمال الاستكشاف وقراءة الشهادات.","Crossing closes World One. You will not be able to return to the library. You may stay now to finish exploring and reading."],
 "stay":["البقاء والاستكشاف","Stay and explore"],
 "depart":["العبور نهائيًا","Cross permanently"],
 "preview_exit_title":["نهاية تجربة البيئة","Environment Tour Complete"],
 "preview_exit_body":["هذه عتبة العالم التالي. المواجهات والعالم الثاني تأتي في مرحلة لاحقة؛ لا تسجل هذه التجربة انتصارًا على حارس أو زعيم.","This is the next world's threshold. Combat and World Two arrive in a later stage. This tour does not award a guardian or boss victory."],
 "explore_more":["العودة للاستكشاف","Keep exploring"],
 "completion_title":["عند عتبة المحاضرة التالية","At the Next Lecture's Threshold"],
 "completion_body":["انتهت تجربة بيئة المكتبة المتحوّلة هنا. احتفظت اليوميات بما قرأته، وحُفظت حلول الألغاز ومساراتك.\n\nالمواجهات والعالم الثاني يأتيان في مرحلة تالية. عبور هذه التجربة لا يمنح ختمًا أو انتصارًا على زعيم.","The Folding Library environment tour ends here. Your journal, puzzle solutions and discovered routes are remembered.\n\nCombat and World Two come in a later stage. Completing this tour awards no seal or boss victory."],
 "completion_count":["المناطق المكتشفة: %s / 15","Areas explored: %s / 15"],
 "locked":["ما زال المسار مغلقًا؛ راجع آلية هذه المنطقة.","This path is still closed. Check the area's mechanism."],
 "already_solved":["الآلية مستقرة ومحفوظة.","The mechanism is settled and remembered."],
 "weapon_found":["أخذت أداة الحارس.","You found the Warden's tool."],
 "book_found":["أضيف الكتاب إلى مجموعتك.","The book joins your collection."],
 "books_complete":["اكتملت الكتب الثلاثة. اتجه إلى طاولة PROCESS.","All three books collected. Find the PROCESS table."],
 "note_read":["حُفظت الشهادة في اليوميات.","Testimony added to your journal."],
 "dialogue_seen":["يظل الغريب هنا إن أردت العودة إليه.","The stranger remains here if you wish to return."],
 "checkpoint_saved":["استراحة. حُفظ تقدمك.","Rest. Your progress is remembered."],
 "mechanism_changed":["تغيّرت الآلية؛ راقب النتيجة.","The mechanism shifts. Watch what changes."],
 "ink_retry":["الحبر عاد إلى الحوض. راجع اتصالات القنوات.","The ink returns to the basin. Check the channel connections."],
 "ink_ready":["وصل الحبر. انتظر استقرار الممشى.","Ink connected. Wait for the walkway to settle."],
 "books_missing":["اجمع الكتب الثلاثة الظاهرة من INPUT أولًا.","First collect all three visible books in INPUT."],
 "order_retry":["الترتيب لا يطابق الدليل. الكتب لم تُفقد.","The order differs from the diagram. No books were lost."],
 "order_verified":["ثُبت الترتيب. جهاز OUTPUT جاهز.","Order verified. OUTPUT is ready."],
 "output_ready":["ابتعد عن الصفحة وانتظر تثبيت الدرج.","Keep clear of the page while the stair settles."],
 "balance_retry":["الكفتان غير متعادلتين. غيّر موضع الأثقال.","The pans are uneven. Move the weights."],
 "balance_ready":["تعادل الميزان. انتظر تثبيت الجسر.","The balance aligns. Wait for the bridge to lock."],
 "overlay_retry":["علامات الصفحتين لم تتطابق بعد.","The two pages' marks do not align yet."],
 "overlay_ready":["اكتمل الرسم. الطية الجانبية تنفتح.","The drawing is whole. The side fold opens."],
 "pop_retry":["راجع رسم الطيات؛ المحاولة التالية جاهزة.","Check the fold diagram. You may try again immediately."],
 "pop_ready":["انفتح الكتاب على حجرة مخفية.","The book opens onto a hidden chamber."],
 "shortcut_open":["فُتح طريق العودة، وسيبقى مفتوحًا.","A return path opens and stays open."],
 "secret_found":["اكتشفت هامشًا منسيًا.","You found a forgotten margin."],
 "seal_missing":["الختم مكافأة حارس هذه الساحة؛ لا تمنحه البيئة.","The seal belongs to this court's guardian. The environment cannot award it."],
 "seal_registered":["تعرّف الباب على ختمك.","The door recognizes your seal."],
 "departure_confirm":["تأكد من إنهاء استكشافك قبل العبور.","Finish exploring before you cross."],
 "unknown_action":["لا تستجيب الآلية بعد.","The mechanism does not respond yet."],
 "fold_committed":["استقر الطريق وحُفظ وضعه.","The path settles. Its state is remembered."],
 "fold_blocked":["ابتعد عن مجال حركة الصفحة أولًا.","First move clear of the page's movement."],
 "objective_1":["خذ الأداة، ثم تابع نحو المحاضرة.","Take the tool, then follow the lecture route."],
 "objective_3":["صل شبكة الحبر لتفتح الممشى.","Connect the ink network to unfold a walkway."],
 "objective_4":["ثمة من ينادي من زاوية الرف.","Someone calls from the shelf's shadow."],
 "objective_6":["اصعد الأرشيف. اقرأ ما تركه الباحثون.","Climb the archive. Read what the searchers left."],
 "objective_7":["اجمع الكتب الثلاثة: △  □  ○","Collect the three books: △  □  ○"],
 "objective_8":["طابق الكتب مع الدليل المرقم.","Match the books to the numbered diagram."],
 "objective_9":["انشر الصفحة من الأرض الثابتة.","Deploy the page from fixed ground."],
 "objective_10":["وازن الأثقال حتى يستقر الجسر.","Balance the weights to settle the bridge."],
 "objective_12":["راقب المكابس وافتح ممشى الخدمة.","Watch the presses and open the service path."],
 "objective_13":["المحكمة خلف ساحة المصحّح.","The tribunal lies beyond the corrector's court."],
 "objective_15":["محاضرة واحدة انتهت. ماذا ينتظر خلف الباب؟","One lecture has ended. What waits beyond the door?"],
 "objective_continue":["الطريق مفتوح؛ تابع الرحلة أو استكشف الهوامش.","The path is open. Continue the journey or explore its margins."],
 "objective_books_count":["كتب INPUT: %s / 3 · اجمع الرموز الثلاثة.","INPUT books: %s / 3 · Collect all three symbols."],
 "objective_default":["استكشف المسارات والهوامش.","Explore the paths and margins."],
 "bench":["استراحة وحفظ","Rest and remember"], "weapon":["أداة الحارس","Warden's tool"],
 "note":["قراءة الشهادة","Read testimony"], "dialogue":["الاقتراب من الغريب","Speak to the stranger"],
 "ink_control":["شبكة الحبر","Ink network"], "book":["أخذ الكتاب","Take book"],
 "process_control":["ترتيب الكتب","Arrange books"], "output_control":["جهاز الإخراج","OUTPUT mechanism"],
 "balance_control":["ميزان التجليد","Binding balance"], "shortcut":["فتح طريق العودة","Open return path"],
 "secret_overlay":["الصفحتان الشفافتان","Translucent pages"], "secret_pop":["الكتاب المجسّم","Pop-up book"],
 "combat_socket":["مقبس الختم","Seal socket"], "world_exit":["العتبة التالية","Next threshold"]
}

const NOTES := {
 "black_flame_warning":["تحذير صاحب الشعلة السوداء","The Black Flame's Warning","شعلتي تضعف داخل هذا العالم. قال الغريب إن بعض المنطفئين يموتون، وآخرين يظلون حاضرين في عذاب. في الأرشيف شهادات عن شيء يعيد إشعال الشعلة؛ مكانه وشكله غير مؤكدين. عليّ أن أقرأ ما كتبه الذين بحثوا عنه، وأنتبه إلى ما ينقص شهاداتهم.","My flame is weakening in this world. The stranger said some whose flames go out die, while others remain present in pain. The archive holds testimonies about something that can kindle a flame again; its form and location are uncertain. I should read what its seekers left behind, and notice what their accounts leave out."],
 "entrance_note":["موعد المحاضرة","The Lecture Schedule","توقفت الساعة عند الموعد نفسه. وتحت الجدول سطر بخط مختلف: «الحضور لا ينتهي بانتهاء الصوت». ","The clock stopped at the same appointment. Beneath the schedule, another hand wrote: ‘Attendance does not end when the voice stops.’"],
 "assignment_note":["دفتر التسليم المتأخر","The Late Submission","سأنهي هذا الواجب، ثم أعود إلى البيت. أعرف أن الطريق يمر من…\n\nبقية الصفحة فارغة، رغم أن الحبر ما زال رطبًا.","I will finish this assignment, then go home. I know the way passes through…\n\nThe rest of the page is blank, although the ink is still wet."],
 "margin_testimony":["اسم ممحو","An Erased Name","قيل إن من يستعيد شعلته يترك أثرًا في الورق. بحثت عن الأثر، فوجدت اسمي وقد مسحه أحدهم. لا أذكر إن كنت أنا من فعل ذلك.","They said those whose flame is restored leave a mark on paper. I searched for that mark and found my own name erased. I cannot remember whether I erased it myself."],
 "archive_water":["الشهادة الأولى: الماء الأسود","Testimony I: Black Water","رأيت ضوءًا في قاع الماء الأسود. كلما اقتربت، سمعت أحدًا يقلب صفحة. لم أنزل. لا تسألني لماذا؛ لا أذكر إلا صوت الصفحة.","I saw a light beneath black water. As I approached, someone turned a page. I did not descend. Do not ask why. I remember only the sound of the page."],
 "archive_door":["الشهادة الثانية: الصوت خلف الباب","Testimony II: The Voice Beyond","كان الباب في المكان الذي وصفه الكتاب. لكن من خلفه ناداني صوت باسم لم يعرفه أحد هنا. عدت في اليوم التالي، فلم أجد الجدار نفسه.","The door stood where the book described. Beyond it, a voice called me by a name no one here knew. I returned the next day. Even the wall was gone."],
 "archive_return":["الشهادة الثالثة: العائد","Testimony III: The Return","عدت وشعلتي قوية كما كانت. وعدتُ شخصًا أن أكتب اسمه هنا حين أصل.\n\nترك الكاتب مكان الاسم فارغًا، ثم كرر كلمة «وعدت» حتى انقطع الحبر.","I returned with my flame strong again. I promised someone I would write their name here when I arrived.\n\nThe writer left the name blank, then repeated ‘I promised’ until the ink ran out."],
 "balance_record":["سجل صيانة الميزان","The Balance Ledger","لا يُرفع جانب إلا بما يُنقل من الآخر. كتب المصلح هذه العبارة في هامش سجل الآلة، ثم شطب كلمة «الآلة».","One side rises only by what is taken from the other. The repairer wrote this in the machine ledger's margin, then crossed out ‘machine’."],
 "projection_note":["المحاضرة المسجلة","The Recorded Lecture","التسجيل يعيد الجملة نفسها: «إذا كانت النتيجة صحيحة، فراجع ما استُهلك للوصول إليها». لا يظهر المحاضر في أي إطار.","The recording repeats one sentence: ‘If the result is correct, inspect what was consumed to obtain it.’ The lecturer appears in none of its frames."],
 "repairer_note":["مذكرة المصلح","The Repairer's Note","الطيات الجديدة سليمة. الأشرطة القديمة لم تعد تحتمل. تركت ممشى الخدمة مفتوحًا لمن يأتي بعدي. لا تعيدوا تشغيل المكبس الذي يسمعكم.","The new folds hold. The old ribbons cannot bear more. I left the service walkway open for whoever follows. Do not restart the press that hears you."],
 "aftermath_note":["محاضرة واحدة","One Lecture","تم إثبات الحضور. يرجى الانتقال إلى المحاضرة التالية.\n\nتحت العبارة، أثر أصابع حاولت تمزيق كلمة «التالية».","Attendance confirmed. Please proceed to the next lecture.\n\nBelow the words, fingerprints mark an attempt to tear out ‘next’."],
 "lab_log":["سجل قنوات الحبر","The Ink Log","الحبر يعيد الطريق إلى شكله المكتوب. إذا عاد إلى الحوض، فراجع جهة اتصال القناة. لا تُعد المحاولة عبئًا على الآلة.","Ink restores the path to its written shape. If it returns to the basin, check the channel's ports. Another attempt does not burden the machine."],
 "process_guide":["إرشاد الطاولة","Table Instructions","الكتب كلها تدخل معًا. لكل كتاب موضع، وترتيب الخانات ظاهر فوق الطاولة. بعد التثبيت تبقى الكتب هنا؛ جهاز الإخراج يتلقى النتيجة.","All books enter together. Each has its place, shown above the table. Once confirmed, the books remain here. OUTPUT receives the result."],
 "tribunal_register":["سجل المحكمة","The Tribunal Register","حُذفت أسماء كثيرة من هذه الصفحة، لكن علامات الحضور بجانبها ما زالت واضحة. في أسفل السجل: «لا تُغلق القاعة حتى يكتمل الحضور».","Many names have been removed from this page, yet their attendance marks remain. At the bottom: ‘Do not close the hall until attendance is complete.’"],
 "missing_names":["أسماء لا تُقرأ","Names That Cannot Be Read","هناك آثار حبر تحت كل محو. بعض الأسماء خُدش بعجلة، وبعضها غُطي بطبقة جديدة من الورق. من عاد ليخفيها مرة أخرى؟","Ink remains beneath every erasure. Some names were scratched out in haste; others covered with fresh paper. Who returned to hide them again?"],
 "secret_2":["رسم عند الرف السفلي","A Sketch Below the Shelf","رسم صغير لبوابة الجامعة. في كل نسخة من الرسم، عدد النوافذ مختلف.","A small drawing of the university gate. Every copy has a different number of windows."],
 "secret_5":["الاسم في الهامش","The Name in the Margin","بقي حرف واحد من الاسم. ويبدو أن أحدًا عاد بعد المحو ليعيد رسمه بعناية.","One letter of the name remains. Someone seems to have returned after the erasure and carefully drawn it again."],
 "secret_6":["شهادة بين صفحتين","Between Two Pages","عند مطابقة الصفحتين ظهر سطر لم يكن مقروءًا: «رأيناه جميعًا. لكن كل واحد منا أقسم أنه رآه في عالم آخر».","When the pages align, a hidden line reads: ‘We all saw it. Yet each of us swore it stood in a different world.’"],
 "secret_9":["رسالة تحت الصفحة","A Letter Under the Page","إن قرأت هذا، فقد وجدت طريقًا صنعته بيديك. تذكر شكله حين يخبرونك أن كل الطرق كانت مرسومة سلفًا.","If you read this, you found a path you made yourself. Remember its shape when they tell you every path was written in advance."],
 "secret_11":["مقعد بلا اسم","A Seat Without a Name","عدد المقاعد أكبر من عدد الأسماء. وبجانب جهاز العرض قائمة حضور لم يُسمح لأحد أن يوقّع آخر سطر فيها.","There are more seats than names. Beside the projector lies an attendance sheet whose last line no one was allowed to sign."],
 "secret_12":["حجرة المصلح","The Repairer's Room","كوب بارد، وشريط جديد، ورسالة لم تُرسل: «ما زال هناك من يصل إلى الأرشيف. سأترك المصباح مضاءً».","A cold cup, a fresh ribbon, and an unsent letter: ‘Someone still reaches the archive. I will leave the lamp burning.’"]
}

const DIALOGUE := [
 ["stranger_speaker","تعال… تعال. إلى أين؟","Come… come here. Where are you going?"],
 ["hero_speaker","أحضر المحاضرات.","To attend the lectures."],
 ["stranger_speaker","واضح عليك التعب. شعلتك بدأت تخف.","You look tired. Your flame is growing faint."],
 ["hero_speaker","شعلتي؟ كيف يعني؟","My flame? What do you mean?"],
 ["stranger_speaker","الطريق صار أثقل؟ وتحتاج أن ترتاح أكثر مما كنت تحتاج؟","Does the road feel heavier? Do you need more rest than before?"],
 ["hero_speaker","نعم… ظننت أنني مرهق فقط.","Yes… I thought I was only exhausted."],
 ["stranger_speaker","كلنا ظننا ذلك في البداية. هذا المكان يأخذ منك قليلًا، ثم قليلًا آخر.","We all thought so at first. This place takes a little from you. Then a little more."],
 ["hero_speaker","وإذا انطفأت؟","And if it goes out?"],
 ["stranger_speaker","إن حالفك الحظ… تموت.","If you are fortunate… you die."],
 ["hero_speaker","وإن لم يحالفني؟","And if I am not?"],
 ["stranger_speaker","تظل حاضرًا.","You remain present."],
 ["hero_speaker","أليس هناك ما يعيدها؟","Is there nothing that can restore it?"],
 ["stranger_speaker","يقولون إن هناك شيئًا يعيد إشعالها كما كانت في أول يوم.","They say something can kindle it again, as it was on the first day."],
 ["hero_speaker","أين؟","Where?"],
 ["stranger_speaker","لو كنت أعرف الطريق، لما بقيت هنا. في الأرشيف شهادات لمن بحثوا عنه. اقرأها… لكن انتبه إلى ما ينقصها.","If I knew the way, I would not still be here. The archive holds testimonies from those who searched. Read them… but notice what is missing."]
]

static func get_text(key: String, language: String = "ar", args: Array = []) -> String:
 var result: String = key
 var index: int = 0 if language == "ar" else 1
 if key.begins_with("room_") and key.trim_prefix("room_").is_valid_int():
  var room_id: int = int(key.trim_prefix("room_"))
  if ROOMS.has(room_id): result = str(ROOMS[room_id][index])
 elif WORDS.has(key):
  result = str(WORDS[key][index])
 if not args.is_empty():
  var needed: int = result.count("%s")
  if needed == args.size(): result = result % args
 return result

static func note(note_id: String, language: String = "ar") -> Dictionary:
 var selected: Array = NOTES.get(note_id, [])
 if selected.is_empty():
  # Layout IDs may describe the same authored note. Keep one stable journal entry.
  var aliases := {"entrance_notice":"entrance_note", "assignment_notice":"assignment_note", "margin_note":"margin_testimony", "archive_note_1":"archive_water", "archive_note_2":"archive_door", "archive_note_3":"archive_return", "balance_note":"balance_record", "projector_note":"projection_note", "bindery_note":"repairer_note", "world_exit_note":"aftermath_note", "note_entrance":"entrance_note", "note_assignments":"assignment_note", "note_lab":"lab_log", "note_alcove":"margin_testimony", "note_archive":"archive_water", "note_archive_upper":"missing_names", "note_process":"process_guide", "note_lecture":"projection_note", "note_tribunal":"tribunal_register", "note_threshold":"aftermath_note", "late_assignment":"assignment_note", "ink_log":"lab_log", "margin_warning":"margin_testimony", "archive_testimony":"archive_water", "lecture_echo":"projection_note", "next_lecture":"aftermath_note", "S01":"secret_2", "S02":"secret_5", "S03":"secret_6", "S04":"secret_9", "S05":"secret_11", "S06":"secret_12"}
  if aliases.has(note_id): selected = NOTES.get(aliases[note_id], [])
 if selected.is_empty():
  return {"title":get_text("note",language), "body":get_text("journal_empty",language)}
 var english: bool = language == "en"
 return {"title":str(selected[1 if english else 0]), "body":str(selected[3 if english else 2])}
