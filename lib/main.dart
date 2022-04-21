import 'package:flutter/material.dart';
import 'package:webxene_core/auth_manager.dart';
import 'package:webxene_core/motes/filter.dart';
import 'package:webxene_core/motes/mote_column.dart';
import 'package:webxene_fpt/sample/sample_group.dart';
import "users/login_screen.dart";
import 'package:webxene_core/group_manager.dart';
import "package:webxene_core/mote_manager.dart";
import 'package:webxene_core/motes/mote.dart';

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
				'/sample': (context) => SampleGroup(),
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
		String ret = "";

		try {
			// Fetch all groups the logged in user has access to.
			final myGroups = await AuthManager().loggedInUser.getSelfGroupsList();
			ret = "Found ${myGroups.length} groups user is part of.\n";
			// Get the specific group we are testing. Normally bound to some kind of selector, etc.
			final groupClicked = myGroups.firstWhere((group) => group.name == "Invoice Group");

			// Fetch a single group + the menu of pages inside it.
			final sampleGroup = await GroupManager().fetchGroup(groupClicked.id);
			ret += "Loaded sample group: ${sampleGroup.id} / ${sampleGroup.name}\n";
			final samplePage = sampleGroup.orderedMenu.firstWhere((page) => page.name == "Invoices");
			ret += "Loaded sample menu-page: ${samplePage.id} / ${samplePage.name} (menu position ${samplePage.menuOrder})\n";

			// Fetch a single page + all data motes inside it.
			final fullSamplePage = await GroupManager().fetchPageAndMotes(samplePage.id, forceRefresh: true);
			ret += "Loaded sample full-page: ${fullSamplePage.id} / ${fullSamplePage.name}\n";
			ret += "Found ${fullSamplePage.cachedMotes.length} motes in sample full-page.\n";

			// Get carddeck columns from this page for rendering.
			ret += "Found ${fullSamplePage.columns.length} columns in sample page:\n";
			ret += fullSamplePage.columns.values.map((c) => c.title).join(", ") + "\n";

			// Fetch all filters possible for a single column.
			MoteColumn sampleColumn = fullSamplePage.columns.values.firstWhere((c) => c.title == "Customers");
			ret += "Selected column: #${sampleColumn.id} ${sampleColumn.title}\n";
			final filterList  = sampleColumn.allPossibleFilters();
			ret += "Possible filters: " + filterList.join(',') + "\n";

			// Add a filter and display matching motes.
			sampleColumn.filters.add(Filter.andFilter("cf_customer_code", 123));
			ret += "Added filter for cf_customer_code = 123\n";
			var moteView = sampleColumn.getMoteView();
			ret += "Got mote view of ${moteView.length} motes from column:\n";
			var interpretation = Mote.interpretMotesCSV(moteView);
			var header = interpretation.item1, data = interpretation.item2;
			ret += header + "\n";
			for (var datum in data) {
				ret += datum + "\n";
			}

			// Remove filter and display all motes.
			sampleColumn.filters.clear();
			moteView = sampleColumn.getMoteView();
			interpretation = Mote.interpretMotesCSV(moteView);
			data = interpretation.item2;
			ret += "Unfiltered data: found ${data.length} motes.\n";

			// Run a benchmark for loading ~100 motes. These are motes with ID from 4508-4600 in group 7.
			final timerLoad = Stopwatch()..start();
			List<int> benchmarkIds = [for (var i = 4508; i <= 4600; i++) i ];
			final sampleMotes = await MoteManager().fetchMotes(benchmarkIds, 7);
			final sampleMotesCSV = Mote.interpretMotesCSV(sampleMotes);
			timerLoad.stop();
			ret += "\n\nBenchmark: Fetched+interpreted ${sampleMotesCSV.item2.length} motes in ${timerLoad.elapsedMilliseconds}ms.";
		} catch (ex) {
			ret += "\n\n" + "*** Encountered exception: $ex ***\n";
		}

		return ret;

	}

}
