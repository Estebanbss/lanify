import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/directory_bloc.dart';
import '../bloc/directory_event.dart';
import '../models/directory_state.dart';

/// Widget de búsqueda para filtrar archivos de audio
class SearchBarWidget extends StatefulWidget {
  const SearchBarWidget({super.key});

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Sincronizar con el estado inicial
    final bloc = context.read<DirectoryBloc>();
    _controller.text = bloc.state.searchFilter;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DirectoryBloc, DirectoryState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _controller,
            onChanged: (value) {
              context.read<DirectoryBloc>().add(ChangeSearchFilter(value));
            },
            decoration: InputDecoration(
              hintText: 'Buscar archivos de audio...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: state.searchFilter.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _controller.clear();
                        context.read<DirectoryBloc>().add(
                          const ChangeSearchFilter(''),
                        );
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        );
      },
    );
  }
}
