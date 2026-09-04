import 'package:flutter/material.dart';

import 'AppColors.dart';

class ConsentDocumentContent extends StatelessWidget {
  const ConsentDocumentContent({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          palette,
          'Propósito',
          'BiPi es una herramienta experimental para estudiantes universitarios. '
              'Compara el momento en que una persona cree que empezará una responsabilidad académica '
              'con el momento en que registra que comenzó.',
        ),
        _buildSection(
          palette,
          'Duración',
          'Una vez iniciado el piloto, tendrá una duración prevista de 14 días.',
        ),
        _buildSection(
          palette,
          'Datos asociados a tu cuenta',
          'La aplicación usa Firebase Auth, que asigna un identificador interno de usuario. '
              'Los datos no son anónimos: quedan asociados a ese identificador.\n\n'
              'En Firestore se almacenan datos operativos como tipo de responsabilidad, '
              'nombre o descripción, fechas, predicción de inicio, momento de inicio registrado, '
              'fuente del registro, respuestas a notificaciones y estado.\n\n'
              'En Firebase Analytics se registran eventos de uso como creación de responsabilidad, '
              'creación de predicción, programación de notificación, selección de acción, '
              'persistencia de respuesta, registro de inicio, visualización de confrontación y uso de Deshacer.\n\n'
              'Firebase Analytics no recibe el nombre libre de la responsabilidad, descripción, correo, '
              'nombre del participante ni contenido académico completo.',
        ),
        _buildSection(
          palette,
          'Finalidad',
          'Los datos se utilizarán únicamente para operar la aplicación durante el piloto, '
              'analizar si el flujo funciona y resolver incidencias técnicas.',
        ),
        _buildSection(
          palette,
          'Conservación de datos',
          'Los datos se conservarán durante el piloto y hasta un máximo de 90 días después de su '
              'finalización.\n\n'
              'La eliminación de los datos será un procedimiento manual realizado por el responsable '
              'del piloto. No existe eliminación automática.',
        ),
        _buildSection(
          palette,
          'Voluntariedad, retiro y eliminación',
          'Participar es voluntario. Puedes dejar de usar la aplicación y solicitar formalmente '
              'tu retiro escribiendo a aggd0001@ce.pucmm.edu.do.\n\n'
              'Para solicitar la eliminación de datos, escribe desde el mismo correo usado al registrarte. '
              'La solicitud será atendida en un máximo de 15 días laborables.\n\n'
              'Retirarte no tendrá consecuencias académicas.',
        ),
        _buildSection(
          palette,
          'Limitaciones',
          'BiPi no diagnostica procrastinación, hábitos, salud mental, rendimiento ni riesgo académico. '
              'No es un servicio de salud, terapia, asesoría académica ni herramienta de vigilancia.',
        ),
        _buildSection(
          palette,
          'Contacto',
          'Responsable: Ángel Gabriel Guzmán Díaz\n'
              'Correo: aggd0001@ce.pucmm.edu.do\n'
              'Contexto: piloto académico independiente desarrollado por un estudiante de PUCMM. '
              'No implica aprobación institucional salvo autorización explícita.',
        ),
      ],
    );
  }

  Widget _buildSection(AppPalette palette, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.label(
              color: palette.textPrimary,
              size: 15,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: AppTypography.body(color: palette.textPrimary, size: 14),
          ),
        ],
      ),
    );
  }
}