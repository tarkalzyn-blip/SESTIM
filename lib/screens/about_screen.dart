import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('لمحة عنا', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.info_outline,
                size: 50,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'نظام إدارة المزرعة الذكي (SESTM)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'الإصدار 1.0.0',
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark 
                  ? Colors.white.withOpacity(0.05) 
                  : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark 
                    ? Colors.white.withOpacity(0.1) 
                    : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'أنا شاب سوري، أبلغ من العمر 25 عامًا. بدأت فكرة هذا التطبيق بدافع شخصي لإثبات قدرتي على بناء شيء حقيقي ونافع.',
                    style: TextStyle(fontSize: 16, height: 1.6),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.1)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'عندما عرضت الفكرة على والدي في البداية، كان رده:',
                          style: TextStyle(fontSize: 14, color: Colors.redAccent, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '"هذا حكي فاضي، ما له فائدة."',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'كان هذا الكلام صعبًا، لكنه كان الدافع الحقيقي للاستمرار وعدم التوقف. قررت أن أكمل الطريق، وأثبت أن الفكرة ممكن أن تتحول إلى شيء عملي يخدم الناس.',
                    style: TextStyle(fontSize: 16, height: 1.6),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'هذا التطبيق هو نتيجة جهد يومي طويل. بعد يوم عمل يمتد من الساعة 8 صباحًا حتى 6 مساءً، كنت أعود إلى المنزل وأخصص وقتي لتطويره وتحسينه بشكل مستمر.',
                    style: TextStyle(fontSize: 16, height: 1.6),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'مع الوقت، تحول من فكرة بسيطة إلى مشروع متكامل يهدف إلى:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                  const SizedBox(height: 12),
                  _buildGoalItem(context, 'تنظيم إدارة المزرعة'),
                  _buildGoalItem(context, 'تسهيل متابعة الأبقار والإنتاج'),
                  _buildGoalItem(context, 'دعم المربي في اتخاذ قرارات أفضل'),
                  const SizedBox(height: 24),
                  const Text(
                    'هدفي هو تقديم أداة عملية وفعالة تساعد مربي الأبقار على إدارة مزارعهم بكفاءة وبأسلوب بسيط.\n\nهذا المشروع ما زال في تطور مستمر، والقادم سيكون أفضل.',
                    style: TextStyle(fontSize: 16, height: 1.6, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'جميع الحقوق محفوظة © 2026',
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'طارق الزوين',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 18, color: Colors.teal.withOpacity(0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
