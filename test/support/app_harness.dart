import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plinth/app/app.dart';
import 'package:plinth/app/providers.dart';

import 'test_env.dart';

Widget harness(TestEnv env) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(env.db),
    attachmentStorageProvider.overrideWithValue(env.storage),
  ],
  child: const PlinthApp(),
);
