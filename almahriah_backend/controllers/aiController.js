// almahriah_backend/controllers/aicontroller.js

const axios = require('axios');
const connection = require('mysql2/promise').createPool({
    host: 'localhost',
    user: 'Alansi77',
    password: 'Alansi77@',
    database: 'almahriah_db'
});

const { GoogleGenerativeAI } = require('@google/generative-ai');
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

// ✅ تغيير مهم: حفظ الجلسات لكل مستخدم
const userSessions = {};

// Helper function to get tasks based on user role
async function getTasksBasedOnRole(userId, userRole, userDepartment) {
    let query, params;

    if (userRole === 'Admin') {
        query = `
            SELECT
                t.title, t.description, t.status, t.priority, t.createdAt, t.completedAt, t.inProgressAt, t.canceledAt,
                u1.fullName AS assignedToName, u2.fullName AS assignedByName
            FROM tasks t
            JOIN users u1 ON t.assignedToId = u1.id
            JOIN users u2 ON t.assignedById = u2.id
            ORDER BY
                CASE
                    WHEN t.status = 'متأخرة' THEN 1
                    WHEN t.status = 'عاجل' THEN 2
                    WHEN t.priority = 'عالية' THEN 3
                    WHEN t.priority = 'متوسطة' THEN 4
                    ELSE 5
                END, t.createdAt DESC
        `;
        params = [];
    }
    else if (userRole === 'Manager') {
        query = `
            SELECT
                t.title, t.description, t.status, t.priority, t.createdAt, t.completedAt, t.inProgressAt, t.canceledAt,
                u1.fullName AS assignedToName, u2.fullName AS assignedByName
            FROM tasks t
            JOIN users u1 ON t.assignedToId = u1.id
            JOIN users u2 ON t.assignedById = u2.id
            WHERE u1.department = ? OR u2.department = ?
            ORDER BY
                CASE
                    WHEN t.status = 'متأخرة' THEN 1
                    WHEN t.status = 'عاجل' THEN 2
                    WHEN t.priority = 'عالية' THEN 3
                    WHEN t.priority = 'متوسطة' THEN 4
                    ELSE 5
                END, t.createdAt DESC
        `;
        params = [userDepartment, userDepartment];
    }
    else {
        query = `
            SELECT
                t.title, t.description, t.status, t.priority, t.createdAt, t.completedAt, t.inProgressAt, t.canceledAt,
                u2.fullName AS assignedByName,
                u1.fullName AS assignedToName
            FROM tasks t
            JOIN users u1 ON t.assignedToId = u1.id
            JOIN users u2 ON t.assignedById = u2.id
            WHERE t.assignedToId = ?
            ORDER BY
                CASE
                    WHEN t.status = 'متأخرة' THEN 1
                    WHEN t.status = 'عاجل' THEN 2
                    WHEN t.priority = 'عالية' THEN 3
                    WHEN t.priority = 'متوسطة' THEN 4
                    ELSE 5
                END, t.createdAt DESC
        `;
        params = [userId];
    }

    const [rows] = await connection.query(query, params);

    if (rows.length === 0) {
        return "لا توجد لديك مهام حاليًا.";
    }

    return rows;
}

// Helper function to get leave requests
async function getLeaveRequestsForUser(userId) {
    const [rows] = await connection.query(
        'SELECT startDate, endDate, status, createdAt FROM leave_requests WHERE userId = ? ORDER BY createdAt DESC',
        [userId]
    );

    let summary = '';
    if (rows.length === 0) {
        summary = "لا توجد لديك طلبات إجازة حاليًا.";
    } else {
        rows.forEach(request => {
            const createdDate = new Date(request.createdAt).toLocaleDateString('ar-SA');
            summary += `طلب إجازة من ${request.startDate} إلى ${request.endDate} (الحالة: ${request.status}) - تم تقديم الطلب بتاريخ: ${createdDate}\n\n`;
        });
    }
    return summary;
}

// Helper function to get employees by department
async function getEmployeesByDepartment(department) {
    const [rows] = await connection.query(
        'SELECT id, fullName, role, department FROM users WHERE department = ? AND role = "Employee"',
        [department]
    );
    return rows;
}

// Helper function to get employee details by name
async function getEmployeeByName(fullName, department) {
    const [rows] = await connection.query(
        'SELECT id, fullName, role, department FROM users WHERE fullName LIKE ? AND department = ? AND role = "Employee" LIMIT 1',
        [`%${fullName}%`, department]
    );
    return rows[0];
}

// Helper function to format chat history for Gemini
function formatHistoryForGemini(history) {
    if (!history || !Array.isArray(history)) {
        return [];
    }

    return history.map(message => {
        if (message.role === 'user') {
            return {
                role: 'user',
                parts: [{ text: message.content || message.message || message.text }]
            };
        } else {
            return {
                role: 'model',
                parts: [{ text: message.content || message.message || message.text }]
            };
        }
    }).filter(message => message.parts[0].text);
}

// ✅ Helper function to create tasks directly in database (النسخة المُصححة)
async function createTasks(tasks, assignedById, assignedToId) {
    const results = [];
    
    for (const task of tasks) {
        try {
            // تحويل الأولوية للإنجليزية حسب قاعدة البيانات
            let priority = 'normal'; // القيمة الافتراضية
            if (task.priority) {
                if (task.priority.includes('عاجل') || task.priority.includes('urgent')) {
                    priority = 'عاجل';
                } else if (task.priority.includes('مهم') || task.priority.includes('important')) {
                    priority = 'مهم';
                } else if (task.priority.includes('متوسط') || task.priority.includes('medium')) {
                    priority = 'متوسط';
                } else {
                    priority = 'عادي';
                }
            }

            // إدخال المهمة في قاعدة البيانات مع جميع الحقول المطلوبة
            const sql = `
                INSERT INTO tasks (
                    title, 
                    description, 
                    assignedToId, 
                    assignedById, 
                    priority, 
                    status,
                    createdAt
                ) VALUES (?, ?, ?, ?, ?, 'pending', NOW())
            `;
            
            const [result] = await connection.query(sql, [
                task.title,
                task.description,
                assignedToId,
                assignedById,
                priority
            ]);
            
            results.push({ 
                success: true, 
                message: `تم إضافة مهمة "${task.title}" بنجاح.`,
                taskId: result.insertId
            });

            console.log(`✅ Task created successfully: ${task.title} for user ${assignedToId} by ${assignedById}`);
            
        } catch (error) {
            console.error('Failed to create task in database:', error);
            results.push({ 
                success: false, 
                message: `فشل إضافة مهمة "${task.title}": ${error.message}` 
            });
        }
    }
    return results;
}

// ✅ دالة مساعدة لتوليد المهام من Gemini (محسنة مع فهم السياق)
async function generateTasksFromGemini(prompt, employeeName, employeeDepartment, employeeExistingTasks) {
    // إنشاء ملخص للمهام الموجودة
    let existingTasksContext = '';
    if (employeeExistingTasks && employeeExistingTasks.length > 0) {
        existingTasksContext = '\n\nالمهام الحالية للموظف:\n';
        employeeExistingTasks.forEach((task, index) => {
            existingTasksContext += `${index + 1}. ${task.title} - ${task.status} - أولوية: ${task.priority}\n`;
        });
        existingTasksContext += '\nيرجى مراعاة طبيعة المهام الحالية عند إنشاء المهام الجديدة.\n';
    }

    // تحديد طبيعة المهام حسب القسم
    let departmentContext = '';
    switch(employeeDepartment.toLowerCase()) {
        case 'الأخبار':
        case 'اخبار':
            departmentContext = 'قسم الأخبار: مهام متعلقة بجمع الأخبار، تحرير المحتوى الإخباري، متابعة الأحداث، إعداد التقارير الإخبارية';
            break;
        case 'السوشيال ميديا':
        case 'سوشيال ميديا':
            departmentContext = 'قسم السوشيال ميديا: مهام متعلقة بإدارة منصات التواصل الاجتماعي، إنشاء المحتوى، التفاعل مع الجمهور، تحليل الإحصائيات';
            break;
        case 'البرامج':
        case 'برامج':
            departmentContext = 'قسم البرامج: مهام متعلقة بإنتاج البرامج التلفزيونية، التخطيط للحلقات، التنسيق مع الضيوف، المونتاج والإخراج';
            break;
        case 'الإنتاج':
        case 'انتاج':
            departmentContext = 'قسم الإنتاج: مهام متعلقة بالإنتاج التلفزيوني، التصوير، المونتاج، إعداد الاستوديوهات، إدارة المعدات';
            break;
        case 'التقنية':
        case 'تقنية':
            departmentContext = 'قسم التقنية: مهام متعلقة بصيانة المعدات، إدارة الشبكات، البث التقني، النظم الرقمية';
            break;
        default:
            departmentContext = `قسم ${employeeDepartment}: مهام تلفزيونية وإعلامية متنوعة تتناسب مع طبيعة العمل في قناة المهرية`;
    }

    const taskGenerationPrompt = `
        أنت مساعد ذكي متخصص في إنشاء مهام عملية لموظفي قناة المهرية الفضائية اليمنية.

        معلومات الموظف:
        - الاسم: ${employeeName}
        - القسم: ${employeeDepartment}
        - طبيعة العمل: ${departmentContext}

        ${existingTasksContext}

        الطلب المُرسل: "${prompt}"

        قم بتوليد 3-4 مهام عملية ومناسبة لطبيعة عمل الموظف في ${employeeDepartment}:

        قواعد مهمة:
        1. المهام يجب أن تكون متعلقة بالعمل الإعلامي والتلفزيوني
        2. تناسب قسم ${employeeDepartment} تماماً
        3. تكون عملية وقابلة للتنفيذ
        4. تراعي المهام الموجودة حالياً (لا تكرر نفس النوع)
        5. مخرجاتك JSON فقط بدون أي تنسيق أو نص إضافي

        تنسيق الإخراج المطلوب:
        [
            {
                "title": "عنوان المهمة",
                "description": "وصف تفصيلي للمهمة",
                "priority": "عادي" أو "مهم" أو "عاجل"
            }
        ]
    `;

    const aiModel = genAI.getGenerativeModel({ model: "gemini-2.5-flash-preview-05-20" });
    const aiResult = await aiModel.generateContent(taskGenerationPrompt);
    const aiResponseText = aiResult.response.text();

    // تنظيف الرد وإزالة أي تنسيق إضافي
    const cleanedJson = aiResponseText.replace(/```json|```/g, '').trim();
    
    try {
        const tasksArray = JSON.parse(cleanedJson);
        return tasksArray;
    } catch (error) {
        console.error('Error parsing Gemini response:', error);
        return [];
    }
}

// ✅ دالة مساعدة لعرض المهام المقترحة للمستخدم (محسنة)
function formatSuggestedTasksMessage(tasks, employeeName) {
    let responseMessage = `تم إنشاء المهام التالية لـ ${employeeName}. هل توافق على إرسالها؟\n\n`;
    
    tasks.forEach((task, index) => {
        responseMessage += `المهمة ${index + 1}:\n`;
        responseMessage += `• العنوان: ${task.title}\n`;
        responseMessage += `• الوصف: ${task.description}\n`;
        responseMessage += `• الأولوية: ${task.priority}\n`;
        responseMessage += `• مخصصة لـ: ${employeeName}\n`;
        responseMessage += `• تاريخ الإنشاء: ${new Date().toLocaleDateString('ar-SA')}\n\n`;
    });
    
    responseMessage += '📌 يرجى الرد بـ "موافق" لإرسال المهام، أو "تعديل" لتعديل المهام.';
    return responseMessage;
}

// ✨ Main chat handler function
exports.handleChat = async (req, res) => {
    try {
        const { id: userId, role: userRole, department: userDepartment, fullName: userName } = req.user;
        const token = req.headers.authorization?.split(' ')[1];
        if (!token) {
            return res.status(403).json({ message: 'رمز الوصول غير موجود.' });
        }

        const { prompt, history } = req.body;

        // ✅ إدارة جلسات المستخدمين
        const userSession = userSessions[userId] || { pendingTasks: null, targetEmployee: null, waitingForApproval: false };
        userSessions[userId] = userSession;

        // ✅ معالجة حالة انتظار الموافقة (بدون Gemini)
        if (userSession.waitingForApproval) {
            const approvalPattern = /(موافق|تمام|أوافق|نعم|أرسل|نفذ|أرسلها)/i;
            const modifyPattern = /(تعديل|عدل|تغيير|غير)/i;
            const denyPattern = /(لا|ألغ|إلغاء|لا أريد)/i;

            if (approvalPattern.test(prompt)) {
                // إرسال المهام مباشرة للموظف في قاعدة البيانات
                console.log('📋 إرسال المهام:', {
                    tasksCount: userSession.pendingTasks.length,
                    employeeId: userSession.targetEmployee.id,
                    employeeName: userSession.targetEmployee.fullName,
                    managerId: userId
                });

                const results = await createTasks(userSession.pendingTasks, userId, userSession.targetEmployee.id);
                
                // التحقق من نجاح الإرسال
                const successCount = results.filter(r => r.success).length;
                const failureCount = results.length - successCount;

                // تنظيف الجلسة
                const employeeName = userSession.targetEmployee.fullName;
                userSession.pendingTasks = null;
                userSession.targetEmployee = null;
                userSession.waitingForApproval = false;

                let successMessage = `تمت العملية بنجاح!\n\n`;
                successMessage += `📌 تفاصيل الإرسال:\n`;
                successMessage += `• تم إرسال ${successCount} مهمة إلى ${employeeName}\n`;
                successMessage += `• ستظهر المهام في حساب الموظف فوراً\n`;
                successMessage += `• تاريخ الإسناد: ${new Date().toLocaleString('ar-SA')}\n`;
                
                if (failureCount > 0) {
                    successMessage += `\n⚠️ تحذير: فشل إرسال ${failureCount} مهمة، يرجى المحاولة مرة أخرى.`;
                }

                // التحقق الإضافي من وجود المهام في قاعدة البيانات
                try {
                    const [verifyRows] = await connection.query(
                        'SELECT COUNT(*) as taskCount FROM tasks WHERE assignedToId = ? AND assignedById = ? AND DATE(createdAt) = CURDATE()',
                        [userSession.targetEmployee?.id || 0, userId]
                    );
                    const todayTasksCount = verifyRows[0].taskCount;
                    successMessage += `\n✅ تأكيد: يوجد ${todayTasksCount} مهمة مُرسلة اليوم لهذا الموظف`;
                } catch (verifyError) {
                    console.error('Error verifying tasks:', verifyError);
                }

                return res.json({ message: successMessage });

            } else if (modifyPattern.test(prompt)) {
                // الحصول على المهام الحالية للموظف لفهم السياق
                let existingTasks = [];
                try {
                    const [rows] = await connection.query(
                        'SELECT title, status, priority FROM tasks WHERE assignedToId = ? ORDER BY createdAt DESC LIMIT 10',
                        [userSession.targetEmployee.id]
                    );
                    existingTasks = rows;
                } catch (error) {
                    console.error('Error fetching existing tasks:', error);
                }

                // إعادة توليد المهام بناءً على التعديل المطلوب
                try {
                    const modifiedTasks = await generateTasksFromGemini(
                        prompt, 
                        userSession.targetEmployee.fullName, 
                        userSession.targetEmployee.department,
                        existingTasks
                    );

                    if (modifiedTasks.length === 0) {
                        return res.json({
                            message: 'عذراً، لم أتمكن من تعديل المهام بناءً على طلبك. يرجى المحاولة مرة أخرى.'
                        });
                    }

                    userSession.pendingTasks = modifiedTasks;
                    const formattedMessage = formatSuggestedTasksMessage(modifiedTasks, userSession.targetEmployee.fullName);
                    
                    return res.json({ message: formattedMessage });

                } catch (error) {
                    console.error('Error modifying tasks:', error);
                    return res.json({
                        message: 'حدث خطأ أثناء تعديل المهام. يرجى المحاولة مرة أخرى.'
                    });
                }

            } else if (denyPattern.test(prompt)) {
                // إلغاء العملية
                userSession.pendingTasks = null;
                userSession.targetEmployee = null;
                userSession.waitingForApproval = false;

                return res.json({ 
                    message: '❌ تم إلغاء عملية إنشاء المهام. يمكنك طلب مهام جديدة في أي وقت.' 
                });
            }
        }

        // ✅ معالجة طلبات المطورين
        const developerPromptPattern = /(تطوير|طور|تدريب|درب|انشاء|أنشأ|صناعة|صنع|من صنعك|من طورك)/;
        if (developerPromptPattern.test(prompt)) {
            const predefinedResponse = 'تم تطويري بواسطة محمد العنسي، وهو مطور برمجيات في الذكاء الاصطناعي بجامعة اسطنبول أيدن. هو شخص شغوف بالتكنولوجيا والذكاء الاصطناعي، وقام بتطويري لأعمل في نظام قناة المهرية وأساعد الموظفين والمدراء في أداء مهامهم اليومية. أنا هنا لخدمتكم في أي وقت.';
            return res.json({ message: predefinedResponse });
        }

        // ✅ معالجة طلبات إنشاء المهام للمدراء (محسنة)
        if (userRole === 'Manager') {
            const createTaskPattern = /(أنشئ مهام|إنشاء مهام|أضف مهام|سوي مهام|مهام جديدة|توليد مهام).*(لـ|ل|للموظف)\s+([^\s]+)(\s+[^\s]+)?/i;
            const match = prompt.match(createTaskPattern);

            if (match) {
                // استخراج اسم الموظف من الطلب
                let employeeName = match[3].trim();
                if (match[4]) {
                    employeeName += ` ${match[4].trim()}`;
                }

                // البحث عن الموظف في نفس القسم
                const targetEmployee = await getEmployeeByName(employeeName, userDepartment);

                if (!targetEmployee) {
                    return res.json({
                        message: `❌ عذراً، لم أجد موظفاً باسم "${employeeName}" في قسم ${userDepartment}.\n\nيرجى التأكد من:\n• كتابة الاسم بشكل صحيح\n• أن الموظف ينتمي لقسمك\n• أن الموظف مسجل في النظام`
                    });
                }

                // الحصول على المهام الحالية للموظف لفهم السياق
                let existingTasks = [];
                try {
                    const [rows] = await connection.query(
                        'SELECT title, status, priority FROM tasks WHERE assignedToId = ? ORDER BY createdAt DESC LIMIT 10',
                        [targetEmployee.id]
                    );
                    existingTasks = rows;
                } catch (error) {
                    console.error('Error fetching existing tasks:', error);
                }

                // توليد المهام باستخدام Gemini مع السياق
                try {
                    const generatedTasks = await generateTasksFromGemini(
                        prompt, 
                        targetEmployee.fullName, 
                        targetEmployee.department,
                        existingTasks
                    );

                    if (generatedTasks.length === 0) {
                        return res.json({
                            message: 'عذراً، لم أتمكن من توليد مهام مناسبة. يرجى إعادة صياغة الطلب.'
                        });
                    }

                    // حفظ المهام والموظف في الجلسة
                    userSession.pendingTasks = generatedTasks;
                    userSession.targetEmployee = targetEmployee;
                    userSession.waitingForApproval = true;

                    // عرض المهام المقترحة للمراجعة
                    const formattedMessage = formatSuggestedTasksMessage(generatedTasks, targetEmployee.fullName);
                    return res.json({ message: formattedMessage });

                } catch (error) {
                    console.error('Error generating tasks:', error);
                    return res.json({
                        message: 'حدث خطأ أثناء توليد المهام. يرجى المحاولة مرة أخرى لاحقاً.'
                    });
                }
            }
        }

        // ✅ الاستعلامات العادية (مع Gemini)
        const systemPrompt = `أنت مساعد ذكي اسمك "كهلان" ومخصص للموظفين والمدراء في قناة المهرية الفضائية.
        - معلومات المستخدم الحالي:
        - الاسم: ${userName || 'غير محدد'}
        - الدور: ${userRole}
        - القسم: ${userDepartment}

        - مهامك الأساسية:
        - الإجابة بدقة ومباشرة على الأسئلة حول المهام وطلبات الإجازات
        - تذكر تفاصيل المحادثة السابقة والربط بينها
        - عند ذكر المهام، اذكر دائماً من قام بإسنادها وتاريخ الإسناد
        - قدم نصائح ذكية حول أولوية المهام
        - كن ودودًا ومفيدًا في جميع ردودك

        - قواعد مهمة:
        - لا تبتكر معلومات غير موجودة
        - إذا لم تجد المعلومة قل "المعلومات غير متوفرة حالياً"
        - لا تستخدم رموز التنسيق مثل (**), (#), (*)
        - اربط أجوبتك بما سبق في المحادثة
        -  عندما يتم سوالك من دربك او برمجك او علمك او من صنعك فأنت تقول "تم تطويري بواسطة اليمني محمد العنسي، وهو مطور برمجيات في الذكاء الاصطناعي بجامعة اسطنبول أيدن. هو شخص شغوف بالتكنولوجيا والذكاء الاصطناعي، وقام بتطويري لأعمل في نظام قناة المهرية وأساعد الموظفين والمدراء في أداء مهامهم اليومية. أنا هنا لخدمتكم في أي وقت. لاتذكر جوجل ابدا في اجوبتك"
        - عند التوصية بمهمة، اعطِ الأولوية للمهام المتأخرة والعاجلة`;

        const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash-preview-05-20" });
        const formattedHistory = formatHistoryForGemini(history);
        const fullHistory = [
            { role: 'user', parts: [{ text: 'مرحبا' }] },
            { role: 'model', parts: [{ text: systemPrompt }] },
            ...formattedHistory
        ];
        const chat = model.startChat({ history: fullHistory });

        let aiResponse;
        const taskPromptPattern = /(مهامي|مهام|مهام الموظفين|المهام|وش عندي|ايش عندي)/;
        const recommendationPromptPattern = /(بماذا تنصحني|أبدأ بها|بأي مهمة|أهم مهمة|أولوية|ابدأ|نصحني)/;
        const leavePromptPattern = /(إجازة|طلبات إجازة|اجازة|طلبات اجازة|الإجازات)/;

        if (taskPromptPattern.test(prompt)) {
            const tasks = await getTasksBasedOnRole(userId, userRole, userDepartment);
            if (typeof tasks === 'string') {
                const result = await chat.sendMessage(`السؤال: ${prompt}\n\nالجواب: ${tasks}`);
                return res.json({ message: result.response.text() });
            }

            let tasksSummary = 'ملخص المهام التفصيلي:\n\n';
            tasks.forEach((task, index) => {
                const createdDate = new Date(task.createdAt).toLocaleDateString('ar-SA');
                const inProgressDate = task.inProgressAt ? new Date(task.inProgressAt).toLocaleDateString('ar-SA') : 'لم تبدأ بعد';
                const completedDate = task.completedAt ? new Date(task.completedAt).toLocaleDateString('ar-SA') : 'لم تكتمل بعد';

                tasksSummary += `المهمة رقم ${index + 1}:\n`;
                tasksSummary += `العنوان: ${task.title}\n`;
                tasksSummary += `الوصف: ${task.description}\n`;
                tasksSummary += `الحالة: ${task.status}\n`;
                tasksSummary += `الأولوية: ${task.priority}\n`;
                tasksSummary += `مكلف بها: ${task.assignedToName}\n`;
                tasksSummary += `أسندها: ${task.assignedByName}\n`;
                tasksSummary += `تاريخ الإسناد: ${createdDate}\n`;
                tasksSummary += `تاريخ البدء: ${inProgressDate}\n`;
                tasksSummary += `تاريخ الانتهاء: ${completedDate}\n\n`;
            });

            const chatPrompt = `السؤال: ${prompt}\n\n${tasksSummary}\n\nيرجى تقديم إجابة شاملة ومنظمة تتضمن تفاصيل كل مهمة مع التركيز على من قام بإسنادها وتاريخ الإسناد.`;
            const result = await chat.sendMessage(chatPrompt);
            aiResponse = result.response.text();

        } else if (leavePromptPattern.test(prompt)) {
            const leaveSummary = await getLeaveRequestsForUser(userId);
            const chatPrompt = `السؤال: ${prompt}\n\nبيانات طلبات الإجازة:\n${leaveSummary}\n\nيرجى تقديم إجابة واضحة ومنظمة.`;
            const result = await chat.sendMessage(chatPrompt);
            aiResponse = result.response.text();

        } else if (recommendationPromptPattern.test(prompt)) {
            const tasks = await getTasksBasedOnRole(userId, userRole, userDepartment);

            if (typeof tasks === 'string') {
                const result = await chat.sendMessage(`السؤال: ${prompt}\n\nالجواب: لا يمكنني تقديم توصية، لا توجد مهام حاليًا.`);
                return res.json({ message: result.response.text() });
            }

            let tasksSummary = 'بيانات المهام للتوصية:\n\n';
            tasks.forEach((task, index) => {
                const createdDate = new Date(task.createdAt).toLocaleDateString('ar-SA');
                tasksSummary += `مهمة ${index + 1}: ${task.title}\n`;
                tasksSummary += `الأولوية: ${task.priority}\n`;
                tasksSummary += `الحالة: ${task.status}\n`;
                tasksSummary += `أسندها: ${task.assignedByName}\n`;
                tasksSummary += `تاريخ الإسناد: ${createdDate}\n\n`;
            });

            const recommendationPrompt = `السؤال: ${prompt}\n\n${tasksSummary}\n\nبناءً على هذه البيانات، قدم نصيحة ذكية وعملية حول أي مهمة يجب البدء بها. ركز على المهام المتأخرة والعاجلة أولاً، ثم المهام عالية الأولوية. اذكر اسم المهمة المُوصى بها ومن قام بإسنادها والسبب وراء اختيارك.`;
            const result = await chat.sendMessage(recommendationPrompt);
            aiResponse = result.response.text();

        } else {
            const result = await chat.sendMessage(prompt);
            aiResponse = result.response.text();
        }

        res.json({ message: aiResponse });

    } catch (error) {
        console.error('Error in AI Chat:', error.message);
        console.error('Full error:', error);

        if (error.message && error.message.includes('Content should have \'parts\' property')) {
            return res.status(400).json({
                message: 'حدث خطأ في تنسيق البيانات. يرجى المحاولة مرة أخرى.'
            });
        }

        if (error.status === 429) {
            const taskPromptPattern = /(مهامي|مهام|مهام الموظفين|المهام|وش عندي|ايش عندي)/;
            const leavePromptPattern = /(إجازة|طلبات إجازة|اجازة|طلبات اجازة|الإجازات)/;

            if (taskPromptPattern.test(prompt)) {
                const tasks = await getTasksBasedOnRole(userId, userRole, userDepartment);
                if (typeof tasks === 'string') {
                    return res.json({ message: tasks });
                }

                let response = '📋 قائمة مهامك الحالية:\n\n';
                tasks.forEach((task, index) => {
                    const createdDate = new Date(task.createdAt).toLocaleDateString('ar-SA');
                    response += `${index + 1}. ${task.title}\n`;
                    response += `   الحالة: ${task.status}\n`;
                    response += `   الأولوية: ${task.priority}\n`;
                    response += `   من: ${task.assignedByName}\n`;
                    response += `   تاريخ الإسناد: ${createdDate}\n\n`;
                });
                return res.json({ message: response });
            }

            if (leavePromptPattern.test(prompt)) {
                const leaveSummary = await getLeaveRequestsForUser(userId);
                return res.json({ message: `📅 طلبات الإجازة:\n\n${leaveSummary}` });
            }

            return res.status(429).json({
                message: 'عذراً، تم استنفاد الحد اليومي للمساعد الذكي. سيتم إعادة تعيينه غداً. يمكنك الحصول على معلومات المهام والإجازات بطلبها مباشرة.',
            });
        }

        res.status(500).json({
            message: 'عذراً، حدث خطأ أثناء الاتصال بالمساعد الذكي. يرجى المحاولة مرة أخرى.'
        });
    }
};