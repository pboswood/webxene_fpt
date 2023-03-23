import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:webxene_core/auth_manager.dart';
import 'package:webxene_core/instance_manager.dart';
import 'package:webxene_core/motes/attachment.dart';
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
			sampleColumn.calculateMoteView();
			var moteView = sampleColumn.getMoteViewPage(pageNum: 0);
			ret += "Got mote view of ${moteView.length} motes from column:\n";
			await Mote.retrieveReferences(moteView, sampleGroup.id);
			var interpretation = Mote.interpretMotesCSV(moteView);
			var header = interpretation.item1, data = interpretation.item2;
			ret += header + "\n";
			for (var datum in data) {
				ret += datum + "\n";
			}

			// Remove filter and display all motes.
			sampleColumn.filters.clear();
			sampleColumn.calculateMoteView();
			moteView = sampleColumn.getMoteViewPage(pageNum: 0);
			await Mote.retrieveReferences(moteView, sampleGroup.id);
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

			// Run global search example
			final searchGlobal = await MoteManager().searchMoteGlobalIndex(
				groupId: 7,
				searchTerms: [ "ref", "cust" ],
				moteTypes: [ InstanceManager().schemaByType("beta_bulkdata"), InstanceManager().schemaByType("beta_customer") ]
			);
			ret += "\n\nFound ${searchGlobal.length} motes from global search: ";
			ret += searchGlobal.map((m) => m.id.toString()).toList().join(', ');

			// Display attachment data from an existing mote (#4964), then fetch it in full (e.g. after clicking).
			final moteWithAttachment = await MoteManager().fetchMote(4964, 7);
			ret += "\n\nLoaded mote with ${moteWithAttachment.attachments.length} attachments:";
			for (var attachment in moteWithAttachment.attachments) {
				ret += "\n${attachment.filename}: ${attachment.mime}, size ${attachment.filesize}";
			}
			if (!moteWithAttachment.attachments.first.isLoaded) {       // If attachment isn't loaded, load it async.
				await moteWithAttachment.attachments.first.loadAttachment();
			}
			ret += "\nDecrypted attachment of ${moteWithAttachment.attachments.first.byteArray?.length ?? 0} bytes successfully!";
			// You can also manually clear the attachment bytes (in RAM) if you are sure you no longer need it (or just wait for Garbage Collection)
			// moteWithAttachment.attachments.first.clearAttachment();

			// Create an attachment with an existing piece of data gathered from file input, etc.
			Uint8List sampleFileBytes = Uint8List.fromList("Example file with data - text/plain".codeUnits);        // Normally loaded from file, etc.
			Attachment newAttachment = Attachment.newFromByteArray("samplefile.txt", "text/plain", sampleFileBytes);
			// Attachment must be uploaded first (allocating an ID) before it can be 'attached' to the mote and then saved.
			await newAttachment.saveAttachmentRemotely();
			ret += "\nUploaded remote attachment with attach ID #${newAttachment.id} (encrypted size ${newAttachment.encryptedBytes?.length ?? 0} bytes)";
			moteWithAttachment.attachments.add(newAttachment);
			// Remove any attachments with the same filename (just to allow this test to run multiple times easily)
			moteWithAttachment.attachments.removeWhere((attach) => attach.filename == 'samplefile.txt' && attach.id != newAttachment.id);
			MoteManager().saveMote(moteWithAttachment);
			ret += "\nSaved mote with new remote attachment successfully (#${moteWithAttachment.id})";

			// Example of updating an existing mote (#4926) by replacing the cf_data_values Text field with the current time.
			Mote updateMote = await MoteManager().fetchMote(4926, 7);
			updateMote.payload['cf_data_values'] = "Updated at ${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}.";
			updateMote = await MoteManager().saveMote(updateMote);      // saveMote returns latest new copy of Mote from server.
			// It may help to reload this mote - saving automatically caches the saved mote, so this is network free.
			updateMote = await MoteManager().fetchMote(updateMote.id, 7);
			ret += "\n\nUpdated and changed Mote #${updateMote.id} data_values = ${updateMote.payload['cf_data_values']}";

			// Example of creating a new mote (simple, root-level with no references or anything else)
			final charlieGroup = await GroupManager().fetchGroup(7);
			final charliePage = charlieGroup.orderedMenu.firstWhere((page) => page.name == "Charlie Testing");
			Mote newRootMote = Mote.fromBlank(
				schema: InstanceManager().schemaByType('charlie_customer'),
				group: charlieGroup,
				page: charliePage,
				author: AuthManager().loggedInUser,
				title: "My New Customer",       // Title can be omitted here and set later via newRootMote.payload['title'], but all motes must have a title before saving.
			);
			newRootMote.payload['cf_full_name'] = "Full name of the customer";
			newRootMote.payload['cf_telephone'] = '+852 91234567';
			newRootMote = await MoteManager().saveMote(newRootMote);
			ret += "\n\nSaved new mote (simple): saved as ID #${newRootMote.id} at timestamp ${newRootMote.timestamp}";

			// Example of creating a new mote with references to another mote (Donation that links to customer above)
			Mote newDonationMote = Mote.fromBlank(
				schema: InstanceManager().schemaByType('charlie_donation'),
				group: charlieGroup,
				page: charliePage,
				author: AuthManager().loggedInUser,
				title: "My New Donation",
			);
			newDonationMote.payload['cf_donated_at'] = '2023-03-18T14:30';
			newDonationMote.payload['amount'] = {
				'amount': 1770,       // At precision 2, this is EUR 17.70. MUST be an integer.
				'currency': 'EUR',
				'precision': 2,
			};
			newDonationMote = await MoteManager().saveMote(newDonationMote);
			ret += "\n\n Saved new mote (reference): saved as ID #${newDonationMote.id} at timestamp ${newDonationMote.timestamp}";

			// Example of creating a new mote inside another subview (e.g. Contact inside an existing Customer).
			// This is functionally the same as creating a mote and adding a reference in it manually (from the parent -> new mote).
			Mote existingCustomer = await MoteManager().fetchMote(821, 7);
			final customerViewPage = charlieGroup.orderedMenu.firstWhere((page) => page.name == "Customer View");   // (Any page where you can view 'contacts' can be used here)
			Mote newChildMote = Mote.fromBlank(
				schema: InstanceManager().schemaByType('beta_contact'),
				group: charlieGroup,
				page: customerViewPage,
				author: AuthManager().loggedInUser,
				title: "Subview contact inside a customer",
				parent: existingCustomer,
			);
			newChildMote.payload['cf_email_address'] = 'email@example.com';
			newChildMote.payload['cf_secret_text'] = 'ABCDE';
			newChildMote = await MoteManager().saveMote(newChildMote);
			// WARNING: You must discard references to parent mote and reload it for most current data, as the cache will NOT
			// have your most recent reference to your newly created mote yet.
			// Either do: existingCustomer = null, or existingCustomer = await MoteManager().fetchMote(821, 7);
			ret += "\n\nSaved new mote (subview): saved as ID #${newChildMote.id} at timestamp ${newChildMote.timestamp}";

			return ret;
		} catch (ex) {
			ret += "\n\n" + "*** Encountered exception: $ex ***\n";
		}

		return ret;

	}

}
