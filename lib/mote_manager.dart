import 'dart:convert';
import 'instance_manager.dart';
import "motes/mote.dart";

class MoteManager {
	static MoteManager? _instance;
	factory MoteManager() => _instance ??= new MoteManager._singleton();
	MoteManager._singleton();       // Empty singleton constructor

	final Map<int, Mote> _moteCache = {};

	// Invalidate the given mote ID or list of IDs.
	invalidateMote(int id) {
		_moteCache.remove(id);
	}
	invalidateMotes(List<int> ids, { bool allMotes = false }) {
		if (allMotes) {
			_moteCache.clear();
		} else {
			for (var id in ids) {
				_moteCache.remove(id);
			}
		}
	}

	// Fetch a single mote as given by the mote ID and a group ID. Usually used only for looking up relations,
	// as we normally fetch a sequence given by a page or something else.
	//Future<Mote> fetchMote(int id, int gid) async {
		// return fetchMotes(List<int>.filled(1, id), gid);
	//}
	Future<List<Mote>> fetchMotes(List<int> ids, int gid) async {
		final List<Mote> returnMotes = [];

		// Take what we can from the mote cache, removing those we satisfy.
		List<int> toFetch = [];
		for (int id in ids) {
			if (_moteCache.containsKey(id)) {
				returnMotes.add(_moteCache[id]!);
			} else {
				toFetch.add(id);
			}
		}

		// If we have a full cache hit, just return this.
		if (toFetch.isEmpty) {
			return returnMotes;
		}

		// Otherwise fetch a list of motes using our API.
		try {
			final List<String> toFetchStr = toFetch.map((e) => e.toString()).toList();
			final fetchRequest = await InstanceManager().apiRequest('motes/relationMotes', {
				"ids[]": toFetchStr,
				'gid': gid.toString(),
			});
			if (!fetchRequest.success(APIResponseJSON.list)) {
				throw Exception("Failed to fetch mote sequence (error " + fetchRequest.response.statusCode.toString() + ")");
			}

			final List<Mote> returnMotes = [];
			final fetchMotes = fetchRequest.result as List;
			for (var m in fetchMotes) {
				try {
					Mote initializedMote = Mote.fromEncryptedJson(m);
					await initializedMote.decryptMote(); // TODO: Can we multi-thread this by using Promise.all dart-equiv?
					returnMotes.add(initializedMote);
					_moteCache[initializedMote.id] = initializedMote;
				} catch (ex) {
					// On failure of initializing a mote (JSON decode / encryption), we 'fetch' nothing.
					print(ex);
				}
			}

			return returnMotes;
		} catch (ex) {
			//throw Exception("Failed to fetch mote sequence");
			rethrow;
		}
	}

}