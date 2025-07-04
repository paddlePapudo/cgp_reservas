// lib/presentation/widgets/booking/reservation_form_modal.dart - VALIDACI├ôN COMPLETA + EMAILS
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/booking_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/firebase_user_service.dart';
import '../../../core/services/user_service.dart';
import '../../../domain/entities/booking.dart';

class ReservationFormModal extends StatefulWidget {
  final String courtId;
  final String courtName;
  final String date;
  final String timeSlot;

  const ReservationFormModal({
    Key? key,
    required this.courtId,
    required this.courtName,
    required this.date,
    required this.timeSlot,
  }) : super(key: key);

  @override
  State<ReservationFormModal> createState() => _ReservationFormModalState();
}

class _ReservationFormModalState extends State<ReservationFormModal> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  
  List<ReservationPlayer> _selectedPlayers = [];
  List<ReservationPlayer> _availablePlayers = [];
  List<ReservationPlayer> _filteredPlayers = [];
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _searchController.addListener(_filterPlayers);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialSlotAvailability();
      _filterPlayers();
    });
  }

  // ≡ƒöÑ VALIDACI├ôN INICIAL: Verificar disponibilidad al abrir modal
  void _checkInitialSlotAvailability() {
    final provider = context.read<BookingProvider>();
    final playerNames = _selectedPlayers.map((p) => p.name).toList();
    
    final validation = provider.canCreateBooking(
      widget.courtId, 
      widget.date, 
      widget.timeSlot, 
      playerNames
    );

    if (!validation.isValid) {
      setState(() {
        _errorMessage = validation.reason;
      });
      
      // Auto-cerrar si hay conflicto inicial
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  void _initializeForm() {
    print('≡ƒÜÇ MODAL: Inicializando formulario...');
    
    // Inicializar listas vac├¡as
    _availablePlayers = [];
    _filteredPlayers = [];
    
    // ≡ƒöÑ USUARIO DIN├üMICO: Configurar usuario actual primero
    _setCurrentUser().then((_) {
      print('Γ£à MODAL: Usuario principal configurado, cargando desde Firebase...');
      // Despu├⌐s cargar usuarios desde Firebase
      _loadUsersFromFirebase();
    });
  }

  /// ≡ƒöÑ NUEVO: Configurar usuario actual din├ímicamente
  /// ≡ƒöÑ NUEVO: Configurar usuario actual din├ímicamente
  Future<void> _setCurrentUser() async {
    try {
      // Obtener usuario actual del servicio
      final currentEmail = await UserService.getCurrentUserEmail();
      final currentName = await UserService.getCurrentUserName();
      
      print('Γ£à MODAL: Usuario actual - $currentName ($currentEmail)');
      
      // Agregar como usuario principal (organizador)
      _selectedPlayers.add(ReservationPlayer(
        name: currentName,
        email: currentEmail,
        isMainBooker: true,
      ));
      
      // ≡ƒöÑ NUEVO: Validar conflictos del organizador inmediatamente
      if (mounted) {
        final provider = context.read<BookingProvider>();
        final playerNames = _selectedPlayers.map((p) => p.name).toList();

        final validation = provider.canCreateBooking(
          widget.courtId,
          widget.date,
          widget.timeSlot,
          playerNames
        );

        if (!validation.isValid) {
          setState(() {
            _errorMessage = validation.reason;
          });

          print('Γ¥î MODAL: Conflicto detectado para organizador: ${validation.reason}');

          // ≡ƒöÑ MOSTRAR SNACKBAR CON EL ERROR
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'ΓÜá∩╕Å ${validation.reason}',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red[600],
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
            ),
          );

          // Auto-cerrar despu├⌐s de mostrar el mensaje
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
        } else {
          print('Γ£à MODAL: Sin conflictos detectados para organizador');
        }
      }
      
    } catch (e) {
      print('Γ¥î MODAL: Error obteniendo usuario actual: $e');
      
      // Fallback de emergencia
      _selectedPlayers.add(ReservationPlayer(
        name: 'USUARIO TEMPORAL',
        email: 'temp@cgp.cl',
        isMainBooker: true,
      ));
    }
  }

  /// ≡ƒöÑ CARGAR USUARIOS DESDE FIREBASE
  Future<void> _loadUsersFromFirebase() async {
    print('≡ƒÜÇ MODAL: Iniciando carga de usuarios desde Firebase...');
    
    try {
      setState(() {
        _isLoading = true;
      });

      // Cargar usuarios reales desde Firebase
      print('≡ƒöÑ MODAL: Llamando a FirebaseUserService.getAllUsers()...');
      final usersData = await FirebaseUserService.getAllUsers();
      
      print('≡ƒöÑ MODAL: Recibidos ${usersData.length} usuarios de Firebase');
      
      // Convertir a ReservationPlayer
      final users = usersData.map((userData) {
        return ReservationPlayer(
          name: userData['name'],
          email: userData['email'],
          isMainBooker: false,
        );
      }).toList();
      
      print('≡ƒöÑ MODAL: Convertidos ${users.length} usuarios a ReservationPlayer');

      final allUsers = users;
      
      setState(() {
        _availablePlayers = allUsers.cast<ReservationPlayer>();
        _isLoading = false;
      });

      print('Γ£à MODAL: ${allUsers.length} usuarios cargados desde Firebase');
      
      // Filtrar inmediatamente para mostrar usuarios
      _filterPlayers();
      
    } catch (e) {
      print('Γ¥î MODAL: Error cargando usuarios: $e');
      
      // Fallback: usar usuarios de prueba EXPANDIDOS
      final fallbackUsers = [
        ReservationPlayer(name: 'ANA M BELMAR P', email: 'ana@buzeta.cl'),
        ReservationPlayer(name: 'CLARA PARDO B', email: 'clara@garciab.cl'),
        ReservationPlayer(name: 'JUAN F GONZALEZ P', email: 'juan@hotmail.com'),
        ReservationPlayer(name: 'PEDRO MARTINEZ L', email: 'pedro.martinez@example.com'),
        ReservationPlayer(name: 'MARIA GONZALEZ R', email: 'maria.gonzalez@example.com'),
        ReservationPlayer(name: 'CARLOS RODRIGUEZ M', email: 'carlos.rodriguez@example.com'),
        ReservationPlayer(name: 'LUIS FERNANDEZ B', email: 'luis.fernandez@example.com'),
        ReservationPlayer(name: 'SOFIA MARTINEZ T', email: 'sofia.martinez@example.com'),
        ReservationPlayer(name: 'DIEGO SANCHEZ L', email: 'diego.sanchez@example.com'),
        // Usuarios VISITA
        ReservationPlayer(name: 'PADEL1 VISITA', email: 'reservaspapudo2@gmail.com'),
        ReservationPlayer(name: 'PADEL2 VISITA', email: 'reservaspapudo3@gmail.com'),
        ReservationPlayer(name: 'PADEL3 VISITA', email: 'reservaspapudo4@gmail.com'),
        ReservationPlayer(name: 'PADEL4 VISITA', email: 'reservaspapudo5@gmail.com'),
      ];
      
      setState(() {
        _availablePlayers = fallbackUsers;
        _isLoading = false;
      });
      
      print('≡ƒöä MODAL: Usando ${fallbackUsers.length} usuarios de fallback');
      _filterPlayers();
    }
  }

  // ≡ƒöÑ M├ëTODO FALTANTE: _filterPlayers
  void _filterPlayers() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredPlayers = _availablePlayers
            .where((player) => 
                !_selectedPlayers.any((selected) => selected.email == player.email))
            .toList();
      } else {
        _filteredPlayers = _availablePlayers
            .where((player) => 
                !_selectedPlayers.any((selected) => selected.email == player.email) &&
                (player.name.toLowerCase().contains(query) ||
                 player.email.toLowerCase().contains(query)))
            .toList();
      }
    });
  }

  // ≡ƒöÑ VALIDACI├ôN AL AGREGAR JUGADOR
  void _addPlayer(ReservationPlayer player) {
    if (_selectedPlayers.length >= 4) return;

    // Validar conflictos antes de agregar
    final provider = context.read<BookingProvider>();
    final testPlayerNames = [..._selectedPlayers.map((p) => p.name), player.name];
    
    final validation = provider.canCreateBooking(
      widget.courtId,
      widget.date, 
      widget.timeSlot,
      testPlayerNames
    );

    if (!validation.isValid) {
      setState(() {
        _errorMessage = validation.reason;
      });
      
      // Limpiar error despu├⌐s de unos segundos
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _errorMessage = null;
          });
        }
      });
      return;
    }

    setState(() {
      _selectedPlayers.add(player);
      _searchController.clear();
      _errorMessage = null; // Limpiar errores previos
      _filterPlayers();
    });
  }

  void _removePlayer(ReservationPlayer player) {
    if (!player.isMainBooker) {
      setState(() {
        _selectedPlayers.remove(player);
        _errorMessage = null; // Limpiar errores al remover
        _filterPlayers();
      });
    }
  }

  bool get _canCreateReservation => _selectedPlayers.length == 4 && _errorMessage == null;

  // ≡ƒöÑ CREACI├ôN DE RESERVA CON VALIDACI├ôN FINAL + EMAILS
  Future<void> _createReservation() async {
    if (!_canCreateReservation) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final provider = context.read<BookingProvider>();
      
      // ≡ƒöÑ VALIDACI├ôN FINAL antes de crear
      final playerNames = _selectedPlayers.map((p) => p.name).toList();
      final validation = provider.canCreateBooking(
        widget.courtId, 
        widget.date, 
        widget.timeSlot,
        playerNames
      );
      
      if (!validation.isValid) {
        throw Exception(validation.reason!);
      }

      // Convertir jugadores a formato BookingPlayer
      final bookingPlayers = _selectedPlayers.map((player) => BookingPlayer(
        name: player.name,
        email: player.email,
        isConfirmed: true,
      )).toList();

      print('≡ƒöÑ Creando reserva con emails: ${widget.courtId} ${widget.date} ${widget.timeSlot}');
      print('≡ƒöÑ Jugadores: ${playerNames.join(", ")}');
      
      // ≡ƒÜÇ NUEVO: Crear reserva CON emails autom├íticos
      final success = await provider.createBookingWithEmails(
        courtNumber: widget.courtId,
        date: widget.date,
        timeSlot: widget.timeSlot,
        players: bookingPlayers,
      );
      
      if (success) {
        // Actualizar UI
        await provider.refresh();
        
        print('≡ƒÄë Reserva creada exitosamente con emails - UI actualizada');

        // Mostrar confirmaci├│n
        _showSuccessDialog();
      } else {
        throw Exception('Error al crear la reserva');
      }
      
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
      print('Γ¥î Error creando reserva: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '┬íReserva Confirmada!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tu reserva de p├ídel ha sido confirmada exitosamente:',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(Icons.sports_tennis, 'Cancha', widget.courtName),
                    _buildDetailRow(Icons.calendar_today, 'Fecha', _formatDisplayDate()),
                    _buildDetailRow(Icons.access_time, 'Hora', widget.timeSlot),
                    _buildDetailRow(Icons.group, 'Jugadores', '${_selectedPlayers.length}'),
                    const SizedBox(height: 8),
                    const Text('Participantes:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    ..._selectedPlayers.asMap().entries.map((entry) {
                      final index = entry.key;
                      final player = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(left: 16, top: 2),
                        child: Text(
                          '${index + 1}. ${player.name}${player.isMainBooker ? ' (Organizador)' : ''}',
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // ≡ƒôº NUEVO: Informaci├│n sobre emails enviados
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.email, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Se han enviado emails de confirmaci├│n a todos los jugadores',
                        style: TextStyle(
                          fontSize: 14, 
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'La grilla ahora debe aparecer en azul indicando "Reservada".',
                style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Cerrar confirmaci├│n
              Navigator.of(context).pop(); // Cerrar modal de reserva
            },
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF2E7AFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'Entendido',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  String _formatDisplayDate() {
    try {
      final parts = widget.date.split('-');
      if (parts.length == 3) {
        const months = ['', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
          'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
        return '${parts[2]} de ${months[int.parse(parts[1])]}';
      }
    } catch (e) {
      // En caso de error, devolver fecha original
    }
    return widget.date;
  }

  @override
  Widget build(BuildContext context) {
    // ≡ƒöÑ TEMPORAL - CONFIRMAR QUE SE USA ESTE ARCHIVO
    print("≡ƒÜÇ MODAL V3 OPTIMIZADO! Sin overflow, compacto y funcional");

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.70, // ≡ƒöº Reducido de 0.75 a 0.70
          minHeight: 300, // ≡ƒöº Reducido de 350 a 300
        ),
        child: Column(
          children: [
            // Header inline optimizado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppConstants.getCourtColorAsColor(widget.courtName),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Text(
                          '≡ƒÄ╛ ',
                          style: TextStyle(fontSize: 18),
                        ),
                        Text(
                          widget.courtName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            ' ΓÇó ${_formatDisplayDate()} ΓÇó ${widget.timeSlot}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Body con padding optimizado
            Expanded(
              child: Form(
                key: _formKey,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), // ≡ƒöº Reducido padding
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ≡ƒöº Jugadores seleccionados SUPER COMPACTA
                        Container(
                          padding: const EdgeInsets.all(12), // Γ£à Aumentado de 8 a 12
                          margin: const EdgeInsets.only(bottom: 12), // Γ£à Aumentado de 8 a 12
                          constraints: const BoxConstraints(
                            minHeight: 60, // Γ£à NUEVO: Altura m├¡nima
                            maxHeight: 80, // Γ£à Aumentado de 45 a 80
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Jugadores (${_selectedPlayers.length}/4)',
                                style: const TextStyle(
                                  fontSize: 15, // Γ£à Aumentado de 14 a 15
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8), // Γ£à Aumentado de 4 a 8
                              
                              // ≡ƒöº JUGADORES EN HORIZONTAL - CORREGIDO
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: _selectedPlayers.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final player = entry.value;
                                      return Container(
                                        margin: const EdgeInsets.only(right: 12), // Γ£à Aumentado margen
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8, 
                                          vertical: 4
                                        ), // Γ£à NUEVO: Padding interno
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: player.isMainBooker 
                                                ? Colors.blue.withOpacity(0.3) 
                                                : Colors.green.withOpacity(0.3)
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // ≡ƒöº C├ìRCULO CON N├ÜMERO - M├üS GRANDE
                                            Container(
                                              width: 22, // Γ£à Aumentado de 18 a 22
                                              height: 22, // Γ£à Aumentado de 18 a 22
                                              decoration: BoxDecoration(
                                                color: player.isMainBooker ? Colors.blue : Colors.green,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '${index + 1}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12, // Γ£à Aumentado de 10 a 12
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8), // Γ£à Aumentado spacing
                                            
                                            // ≡ƒöº NOMBRE DEL JUGADOR - MEJORADO
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 100), // Γ£à NUEVO: Ancho m├íximo
                                              child: Text(
                                                player.name.length > 15 
                                                    ? '${player.name.substring(0, 15)}...' // Γ£à Aumentado de 12 a 15 caracteres
                                                    : player.name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 12, // Γ£à Aumentado de 11 a 12
                                                  color: player.isMainBooker ? Colors.blue.shade700 : Colors.black87,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            
                                            // ≡ƒöº BOT├ôN REMOVER - M├üS GRANDE Y VISIBLE
                                            if (!player.isMainBooker) ...[
                                              const SizedBox(width: 6),
                                              InkWell(
                                                onTap: () => _removePlayer(player),
                                                borderRadius: BorderRadius.circular(12),
                                                child: Container(
                                                  padding: const EdgeInsets.all(2), // Γ£à NUEVO: Padding para ├írea t├íctil
                                                  child: const Icon(
                                                    Icons.remove_circle, 
                                                    color: Colors.red, 
                                                    size: 18 // Γ£à Aumentado de 14 a 18
                                                  ),
                                                ),
                                              ),
                                            ],
                                            
                                            // ≡ƒöº INDICADOR DE ORGANIZADOR
                                            if (player.isMainBooker) ...[
                                              const SizedBox(width: 4),
                                              const Icon(
                                                Icons.star, 
                                                color: Colors.amber, 
                                                size: 14
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ≡ƒöº OPCIONAL: Agregar indicador de scroll si hay muchos jugadores
                        if (_selectedPlayers.length > 3)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.swipe,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Desliza para ver todos los jugadores',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),                        
                        if (_selectedPlayers.length < 4) ...[
                          // Campo de b├║squeda
                          Text(
                            'Buscar jugador ${_selectedPlayers.length + 1} de 4:',
                            style: const TextStyle(
                              fontSize: 14, // ≡ƒöº Reducido de 16 a 14
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6), // ≡ƒöº Reducido de 8 a 6
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Buscar por nombre...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // ≡ƒöº Reducido padding
                            ),
                          ),
                          
                          const SizedBox(height: 8), // ≡ƒöº Reducido de 12 a 8
                          
                          // ≡ƒöº Lista de jugadores disponibles M├üS COMPACTA
                          Container(
                            height: 150, // ≡ƒöº Reducido de 200 a 150
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _filteredPlayers.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Text(
                                        _searchController.text.isEmpty
                                            ? 'Escribe para buscar jugadores'
                                            : 'No se encontraron jugadores',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14, // ≡ƒöº Reducido de 16 a 14
                                        ),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(vertical: 2), // ≡ƒöº Reducido padding
                                    itemCount: _filteredPlayers.length,
                                    itemBuilder: (context, index) {
                                      final player = _filteredPlayers[index];
                                      final isSpecialVisit = ['PADEL1 VISITA', 'PADEL2 VISITA', 'PADEL3 VISITA', 'PADEL4 VISITA']
                                          .contains(player.name.toUpperCase());
                                      
                                      return Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), // ≡ƒöº Reducido margins
                                        decoration: BoxDecoration(
                                          color: isSpecialVisit ? Colors.orange.withOpacity(0.1) : Colors.white,
                                          borderRadius: BorderRadius.circular(6), // ≡ƒöº Reducido border radius
                                          border: Border.all(
                                            color: isSpecialVisit ? Colors.orange.withOpacity(0.3) : Colors.grey[200]!
                                          ),
                                        ),
                                        child: ListTile(
                                          dense: true, // ≡ƒöº NUEVO: Hacer m├ís compacto
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), // ≡ƒöº Reducido padding
                                          title: Text(
                                            player.name,
                                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13), // ≡ƒöº Reducido font
                                          ),
                                          subtitle: isSpecialVisit 
                                              ? const Text(
                                                  'Puede jugar en m├║ltiples canchas',
                                                  style: TextStyle(fontSize: 10, color: Colors.orange), // ≡ƒöº Reducido font
                                                )
                                              : null,
                                          trailing: IconButton(
                                            onPressed: () => _addPlayer(player),
                                            icon: Icon(
                                              Icons.add_circle, 
                                              color: isSpecialVisit ? Colors.orange : Colors.green, 
                                              size: 20 // ≡ƒöº Reducido de 24 a 20
                                            ),
                                            constraints: const BoxConstraints(minWidth: 30, minHeight: 30), // ≡ƒöº Constraints m├ís peque├▒os
                                          ),
                                          onTap: () => _addPlayer(player),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                        
                        const SizedBox(height: 8), // ≡ƒöº Reducido de 12 a 8
                        
                        // ≡ƒöÑ MENSAJE DE ERROR MEJORADO
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(10), // ≡ƒöº Reducido padding
                            margin: const EdgeInsets.only(bottom: 12), // ≡ƒöº Reducido margin
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.withOpacity(0.3)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(Icons.error, color: Colors.red, size: 18), // ≡ƒöº Reducido tama├▒o
                                ),
                                const SizedBox(width: 6), // ≡ƒöº Reducido spacing
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Conflicto de horario:',
                                        style: TextStyle(
                                          color: Colors.red, 
                                          fontSize: 13, // ≡ƒöº Reducido font
                                          fontWeight: FontWeight.w600
                                        ),
                                      ),
                                      const SizedBox(height: 2), // ≡ƒöº Reducido spacing
                                      Text(
                                        _errorMessage!,
                                        style: const TextStyle(color: Colors.red, fontSize: 12), // ≡ƒöº Reducido font
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // ≡ƒôº NUEVO: Indicador de progreso de emails
                        Consumer<BookingProvider>(
                          builder: (context, provider, child) {
                            if (provider.isSendingEmails) {
                              return Container(
                                padding: const EdgeInsets.all(10), // ≡ƒöº Reducido padding
                                margin: const EdgeInsets.only(bottom: 12), // ≡ƒöº Reducido margin
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const SizedBox(
                                      width: 14, // ≡ƒöº Reducido tama├▒o
                                      height: 14, // ≡ƒöº Reducido tama├▒o
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    const SizedBox(width: 10), // ≡ƒöº Reducido spacing
                                    Text(
                                      '≡ƒôº Enviando confirmaciones por email...',
                                      style: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontSize: 13, // ≡ƒöº Reducido font
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                        
                        // Botones de acci├│n
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8), // ≡ƒöº Reducido padding
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(color: Colors.red[300]!, width: 1.5),
                                  ),
                                ),
                                child: Text(
                                  'Cancelar',
                                  style: TextStyle(fontSize: 16, color: Colors.red[700], fontWeight: FontWeight.w600), // ≡ƒöº Mejorado contraste
                                ),
                              ),
                            ),
                            const SizedBox(width: 10), // ≡ƒöº Reducido spacing
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: _canCreateReservation && !_isLoading
                                    ? _createReservation
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _canCreateReservation
                                      ? const Color(0xFF2E7AFF)
                                      : Colors.grey[300],
                                  padding: const EdgeInsets.symmetric(vertical: 8), // ≡ƒöº Reducido padding
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 16, // ≡ƒöº Reducido tama├▒o
                                        width: 16, // ≡ƒöº Reducido tama├▒o
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Text(
                                        _canCreateReservation
                                            ? 'Confirmar Reserva'
                                            : _errorMessage != null
                                                ? 'Resolver conflictos'
                                                : 'Elije + ${4 - _selectedPlayers.length} players +',
                                        style: TextStyle(
                                          fontSize: 14, // ≡ƒöº Reducido font
                                          fontWeight: FontWeight.w600,
                                          color: _canCreateReservation ? Colors.white : Colors.grey[600],
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// Clase auxiliar para jugadores en el formulario
class ReservationPlayer {
  final String name;
  final String email;
  final bool isMainBooker;

  ReservationPlayer({
    required this.name,
    required this.email,
    this.isMainBooker = false,
  });
}
