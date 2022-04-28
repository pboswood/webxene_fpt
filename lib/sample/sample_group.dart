import 'package:flutter/material.dart';
import 'package:webxene_core/auth_manager.dart';
import 'package:webxene_core/group_manager.dart';
import 'package:webxene_core/groups/group.dart';
import 'package:webxene_core/motes/filter.dart';
import 'package:webxene_core/motes/mote.dart';
import 'package:webxene_core/motes/mote_column.dart';

class SampleGroup extends StatelessWidget {
	const SampleGroup({Key? key}) : super(key: key);
	@override Widget build(BuildContext context) {

		return FutureBuilder(
			future: _getSampleGroup(),
			builder: (BuildContext context, AsyncSnapshot<List<Mote>> snapshot) {
				if (snapshot.connectionState == ConnectionState.waiting || snapshot.connectionState == ConnectionState.none) {
					return Scaffold(
						appBar: AppBar(title: const Text("Loading...")),
						body: const Center(
							child: CircularProgressIndicator(),
						),
					);
				}

				return Scaffold(
					appBar: AppBar(title: const Text("Adressverwaltung: Kontakte")),
					body: ListView.builder(
						itemCount: snapshot.data?.length ?? 0,
						itemBuilder: (context, index) {
							String subtitle = snapshot.data?[index].payload['cf_adresse'] ?? "";
							subtitle += "\n" + (snapshot.data?[index].payload['cf_telefon'] ?? "");
							return Card(
								margin: const EdgeInsets.only(bottom: 10),
								child: ListTile(
									leading: const Icon(Icons.contact_phone, size: 36),
									title: Text(snapshot.data?[index].payload['title'] ?? ""),
									subtitle: Text(subtitle),
								),
							);
						}
					),
					/*
					floatingActionButton: FloatingActionButton(
						backgroundColor: Colors.blueGrey,
						child: const Icon(Icons.saved_search),
						onPressed: () {

						},
					),
					*/
				);
			},
		);
	}
}

Future<List<Mote>> _getSampleGroup() async {
	int targetGroupId = 1;
	int targetPageId = 6;
	int targetColumnId = 1;

	try {
		final myGroups = await AuthManager().loggedInUser.getSelfGroupsList();
		final myGroupsSelection = myGroups.firstWhere((g) => g.id == targetGroupId);
		final targetGroup = await GroupManager().fetchGroup(myGroupsSelection.id);
		final targetPage = targetGroup.orderedMenu.firstWhere((p) => p.id == targetPageId);
		final fullPage = await GroupManager().fetchPageAndMotes(targetPage.id, forceRefresh: true);
		final targetColumn = fullPage.columns[targetColumnId]!;
		targetColumn.filters.clear();
		final motes = targetColumn.getMoteView();
		final motesCSV = Mote.interpretMotesCSV(motes);
		final motesHeader = motesCSV.item1;
		print(motesHeader);
		final motesData = motesCSV.item2;
		print(motesData);

		targetColumn.filters.add(Filter.andFilter("title", "Kaufmann"));
		final filteredMotes = Mote.interpretMotesCSV(targetColumn.getMoteView());
		print(filteredMotes.item1);     // Header
		print(filteredMotes.item2);     // Data

		return motes;
	} catch (ex) {
		return [];
	}
/*

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

	return ret.split("\n");
*/
}