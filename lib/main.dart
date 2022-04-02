import 'package:flutter/material.dart';
import 'mote_manager.dart';
import 'group_manager.dart';
import 'motes/mote.dart';
import "users/login_screen.dart";

void main() {
	runApp(
		const MaterialApp(
			title: 'Netxene', // used by the OS task switcher
			home: SafeArea(
				child: NetxeneApp(),
			),
		),
	);
}

class NetxeneApp extends StatelessWidget {
	const NetxeneApp({Key? key}) : super(key: key);

	@override Widget build(BuildContext context) {
		return MaterialApp(
			title: "Netxene Test App",
			theme: ThemeData(
				primarySwatch: Colors.blue,
			),
			routes: {
				'/': (context) => LoginScreen(),
				'/home': (context) => HomeWidget(),
			},
		);
	}
}

class HomeWidget extends StatelessWidget {
	const HomeWidget({Key? key}) : super(key: key);

	@override Widget build(BuildContext context) {
		return FutureBuilder<String>(
			future: sampleMoteFetch(),
			builder: (context, AsyncSnapshot<String> snapshot) {
				return Scaffold(
					appBar: AppBar(title: const Text("Home page")),
					body: SingleChildScrollView(
						child: Column(
							children: [
								const Padding(padding: EdgeInsets.all(20)),
								const Center(child: Text("Authentication is complete!")),
								const Padding(padding: EdgeInsets.all(20)),
								snapshot.hasData ? Text(snapshot.data ?? "(No data)", textAlign: TextAlign.center) : const CircularProgressIndicator()
							],
						),
					),
				);
			},
		);
	}

	// Sample fetch for motes of data.
	Future<String> sampleMoteFetch() async {
		final sampleGroup = await GroupManager().fetchGroup(6);
		print("Loaded sample group: ${sampleGroup.id} / ${sampleGroup.name}");
		final samplePage = sampleGroup.orderedMenu.firstWhere((page) => page.name == "Invoices");
		print("Loaded sample page: ${samplePage.id} / ${samplePage.name} (menu position ${samplePage.menuOrder})");

		// (Normally you would know which motes ID numbers to fetch from the page, but we need a CardDeck column implementation first!)

		List<int> benchmarkIds = [];
		for (int i = 4508; i <= 4600; i++) {
			benchmarkIds.add(i);
		}
		// final sampleMotes = await MoteManager().fetchMotes([773, 774, 775], 6);
		final sampleMotes = await MoteManager().fetchMotes(benchmarkIds, 7);

		List<dynamic> sampleMotesCSV = [];
		for (Mote m in sampleMotes) {
			sampleMotesCSV.add(m.motePayloadCSV());
		}

		// TODO: Middleware to consolidate + normalize headers for CSV output and return only CSV strings.
		String ret = "Fetched ${sampleMotes.length} data motes:\n\n";
		for (var mote in sampleMotes) {
			var moteTitle = mote.payload['title'] ?? "(Unnamed)";
			ret += "----- #${mote.id}: $moteTitle -----\n\n";
			var payloadJSON = mote.payload.toString();
			var payloadCSV = mote.motePayloadCSV();
			var payloadHeadersCSV = mote.motePayloadHeadersCSV();
			ret += payloadJSON + "\n\n";
			ret += payloadCSV + "\n\n";
			ret += payloadHeadersCSV + "\n\n";
		}
		return ret;

	}

}
