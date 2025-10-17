import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- CONSTANTES GLOBALES (Centralizadas aquí para el Onboarding) ---
const Color _PRIMARY_COLOR = Color(0xFF601272); 
const Color _ACCENT_COLOR = Color(0xFFFFD900);
// --- FIN CONSTANTES GLOBALES ---


/// Estructura para definir el contenido de cada diapositiva.
class OnboardSlide {
  final String title;
  final String subtitle;
  final String imagePath; 
  final Color visualAccentColor;

  OnboardSlide({
    required this.title,
    required this.subtitle,
    required this.imagePath, 
    required this.visualAccentColor,
  });
}

final List<OnboardSlide> onboardSlides = [
  OnboardSlide(
    title: "Gana dinero extra esta semana.",
    subtitle: "Trabajos flexibles pensados para estudiantes y tu horario.",
    imagePath: 'assets/images/visual1.png', 
    visualAccentColor: _PRIMARY_COLOR, 
  ),
  OnboardSlide(
    title: "Tú pones las horas, no el jefe.",
    subtitle: "Elige trabajos que encajen perfectamente en tu vida académica.",
    imagePath: 'assets/images/visual2.png', 
    visualAccentColor: _ACCENT_COLOR, 
  ),
  OnboardSlide(
    title: "Confianza y pagos garantizados.",
    subtitle: "Todos los trabajos son verificados. Recibe tu pago directamente en tu cuenta cada semana.",
    imagePath: 'assets/images/visual3.png', 
    visualAccentColor: _PRIMARY_COLOR, 
  ),
];


// --- WIDGET PRINCIPAL ---

class BenefitSlidesScreen extends StatefulWidget {
  const BenefitSlidesScreen({super.key});

  @override
  State<BenefitSlidesScreen> createState() => _BenefitSlidesScreenState();
}

class _BenefitSlidesScreenState extends State<BenefitSlidesScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, 'welcome');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // --- WIDGETS DE COMPONENTES ---

  // Genera el contenido visual de cada diapositiva
  Widget _buildSlide(OnboardSlide slide, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          // Contenedor para la imagen de la mascota
          Container(
            // ✅ CAMBIO: Padding reducido para que la imagen se vea más grande dentro del círculo
            padding: const EdgeInsets.all(10), 
            decoration: BoxDecoration(
              color: slide.visualAccentColor.withOpacity(0.1), 
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              slide.imagePath,
              // ✅ CAMBIO: Mayor altura y ancho para más protagonismo
              height: 200.0, 
              width: 200.0,
              fit: BoxFit.contain, 
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.error, size: 100, color: Colors.red);
              },
            ),
          ),
          // ✅ CAMBIO: Espacio un poco menor después de la imagen
          const SizedBox(height: 40.0), 
          
          // Título principal (Destacado)
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayLarge!.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 30, 
              fontWeight: FontWeight.w900, 
            ),
          ),
          const SizedBox(height: 16.0),
          
          // Subtítulo descriptivo
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge!.copyWith(
              color: Colors.grey.shade700,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // Genera los puntos indicadores de posición (Dots)
  Widget _buildDot(int index, Color primaryColor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      height: 8.0,
      width: _currentPage == index ? 24.0 : 8.0,
      decoration: BoxDecoration(
        color: _currentPage == index ? primaryColor : primaryColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // --- BUILD PRINCIPAL ---

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color secondaryColor = Theme.of(context).colorScheme.secondary;
    final isLastPage = _currentPage == onboardSlides.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _currentPage > 0
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: primaryColor),
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeIn,
                  );
                },
              )
            : null, 
        actions: [
          if (!isLastPage)
            TextButton(
              onPressed: () {
                _completeOnboarding();
              },
              child: Text('SALTAR', style: TextStyle(color: primaryColor.withOpacity(0.7), fontWeight: FontWeight.bold, fontSize: 14)),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: onboardSlides.length,
              onPageChanged: (int page) {
                setState(() {
                  _currentPage = page;
                });
              },
              itemBuilder: (context, index) {
                return _buildSlide(onboardSlides[index], context);
              },
            ),
          ),
          
          Container(
            padding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 40.0), 
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12, 
                  blurRadius: 10, 
                  offset: Offset(0, -5)
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    onboardSlides.length,
                    (index) => _buildDot(index, primaryColor),
                  ),
                ),
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentPage < onboardSlides.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeIn,
                        );
                      } else {
                        _completeOnboarding();                        
                        
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLastPage ? secondaryColor : primaryColor, 
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 4,
                    ),
                    child: Text(
                      isLastPage ? 'COMENZAR AHORA' : 'SIGUIENTE',
                      style: Theme.of(context).textTheme.labelLarge!.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isLastPage ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}