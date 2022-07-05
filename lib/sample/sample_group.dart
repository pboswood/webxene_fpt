import 'package:flutter/material.dart';
import 'package:webxene_core/auth_manager.dart';
import 'package:webxene_core/group_manager.dart';
import 'package:webxene_core/groups/group.dart';
import 'package:webxene_core/instance_manager.dart';
import 'package:webxene_core/mote_manager.dart';
import 'package:webxene_core/motes/filter.dart';
import 'package:webxene_core/motes/mote.dart';
import 'package:webxene_core/motes/mote_column.dart';
import 'package:webxene_core/motes/mote_relation.dart';
import 'package:webxene_core/motes/sort_method.dart';

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
							// The subtitle for each item in our list should contain address, telefone, and categories.
							String subtitle = snapshot.data?[index].payload['cf_adresse'] ?? "";
							subtitle += "\n" + (snapshot.data?[index].payload['cf_telefon'] ?? "");
							// Get all relations as motes, then convert them into string separated by commas.
							var categoryRelations = snapshot.data?[index].payload['cf_kategorie'] as List;
							var categoryNames = MoteRelation
								.asMoteList(categoryRelations, snapshot.data?[index].id ?? 0)
								.map((m) => m.payload['title'] ?? '(Unknown)');
							subtitle += "\n" + categoryNames.join(', ');

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

	// This is equivalent to: https://crm.sevconcept.ch/#!/group/1/page/7/view/129
	int specialPageId = 7;
	int specialPageSubmote = 129;

	try {
		// Normal example
		final myGroups = await AuthManager().loggedInUser.getSelfGroupsList();
		final myGroupsSelection = myGroups.firstWhere((g) => g.id == targetGroupId);
		final targetGroup = await GroupManager().fetchGroup(myGroupsSelection.id);
		final targetPage = targetGroup.orderedMenu.firstWhere((p) => p.id == targetPageId);
		final fullPage = await GroupManager().fetchPageAndMotes(targetPage.id, forceRefresh: true);
		final targetColumn = fullPage.columns[targetColumnId]!;
		targetColumn.filters.clear();
		targetColumn.calculateMoteView();                               // Call once every time filters/sort changes or when initializing column.
		final motes = targetColumn.getMoteViewPage(pageNum: 0);         // Gets 20 motes from page 0.
		await Mote.retrieveReferences(motes, targetGroupId);            // Get all references from those 20 motes.

		final motesCSV = Mote.interpretMotesCSV(motes);
		final motesHeader = motesCSV.item1;
		print(motesHeader);
		final motesData = motesCSV.item2;
		print(motesData);
		
		// Sorting example
		print("Sorting:");
		targetColumn.sortMethods.add(SortMethod.normalSort("title", true));
		targetColumn.calculateMoteView();
		final sortedMotes = targetColumn.getMoteViewPage(pageNum: 0);
		print(sortedMotes.map((m) => m.payload['title']).toList());
		targetColumn.sortMethods.clear();

		// Filtering example
		print("Filtering:");
		targetColumn.filters.add(Filter.andFilter("title", "Kaufmann"));
		targetColumn.calculateMoteView();
		final filteredMotes = Mote.interpretMotesCSV(targetColumn.getMoteViewPage(pageNum: 0));
		final filteredMoteDescription = targetColumn.getMoteViewPage(unpaginated: true).map((m) => "#${m.id} - ${m.payload['title']}");
		print("Found ${filteredMoteDescription.length} in filtered motes: ${filteredMoteDescription.join(', ')}");
		print(filteredMotes.item1);     // Header
		print(filteredMotes.item2);     // Data

		// Special page example (e.g. fetching all contacts inside company mote #129)
		// This is equivalent to: https://crm.sevconcept.ch/#!/group/1/page/7/view/129
		final specialPage = await GroupManager().fetchPageAndMotes(specialPageId, forceRefresh: true, subviewMote: specialPageSubmote);
		final specialColumnContacts = specialPage.columns[1];       // 'Kontakte' column
		final specialColumnNotes = specialPage.columns[2];          // 'Notizen' column
		specialColumnContacts?.calculateMoteView();
		specialColumnNotes?.calculateMoteView();
		final List<Mote> contactsView = specialColumnContacts?.getMoteViewPage(unpaginated: true) ?? [];
		final List<Mote> notesView = specialColumnNotes?.getMoteViewPage(unpaginated: true) ?? [];
		// Fetch all references from both at once - or we wait a lot longer for 2 HTTP round trips!
		await Mote.retrieveReferences(contactsView + notesView, targetGroupId);

		print("Found ${contactsView.length} contacts and ${notesView.length} notes!");
		// Print each note title followed by company it is from (called ref2 internally)
		for (var note in notesView) {
			var companyRefs = MoteRelation.asMoteList(note.payload['cf_*ref2'], note.id);
			print(note.payload['title'] + ": " + companyRefs.map((c) => c.payload['title']).toList().join(", "));
		}

		// Search mote index example. This will search for any mote with a specific title
		// (or other indexed content) in a single group, restricted by schema types we are interested in.
		final searchGlobal = await MoteManager().searchMoteGlobalIndex(
			groupId: targetGroupId,
			searchTerms: [ "patrick" ],
			moteTypes: [ InstanceManager().schemaByType("a1_kontaktedetails") ]
		);
		for (var moteMatch in searchGlobal) {
			print("Found in global search: ${moteMatch.id} ${moteMatch.payload['title']}\n");
		}

		return motes;
	} catch (ex) {
		print("EXCEPTION:");
		print(ex);
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