import 'dart:convert';
import 'groups/group.dart';
import 'groups/page.dart';
import 'instance_manager.dart';

// Manager for handling all group and page fetches and caching.
class GroupManager {
	static GroupManager? _instance;
	factory GroupManager() => _instance ??= new GroupManager._singleton();
	GroupManager._singleton();       // Empty singleton constructor

	final Map<int, Group> _groupCache = {};
	final Map<int, Page> _pageCache = {};

	// Invalidate a given group or all of them. Invalidating a group will clear
	// the pages of this group as well.
	invalidateGroup(int id) {
		_groupCache.remove(id);
		_pageCache.removeWhere((key, value) => value.groupId == id);
	}
	invalidateAllGroups() {
		_groupCache.clear();
		_pageCache.clear();
	}

	// Invalidate a page or list of pages.
	invalidatePage(int id) {
		_pageCache.remove(id);
	}
	invalidatePages(List<int> ids, { bool allPages = false }) {
		if (allPages) {
			_pageCache.clear();
		} else {
			for (int id in ids) {
				_pageCache.remove(id);
			}
		}
	}

	// Fetch a single group and all pages related to it.
	Future<Group> fetchGroup(int id) async {
		// If we have a cache hit, just return that.
		if (_groupCache.containsKey(id)) {
			return _groupCache[id]!;
		}

		// Otherwise fetch from our API.
		final apiGroup = await InstanceManager().apiRequest('groups/' + id.toString());
		if (!apiGroup.success(APIResponseJSON.map)) {
			throw Exception("Failed to fetch group (error " + apiGroup.response.statusCode.toString() + ")");
		}

		final groupObj = Group.fromJson(apiGroup.result);
		// Parse out all pages into our page cache as well.
		if (groupObj.orderedMenu.isNotEmpty) {
			for (Page p in groupObj.orderedMenu) {
				_pageCache[p.id] = p;
				// TODO: What about existing pages? How do we know the last fetch wasn't a 'full' fetch with motes, etc. and thus more recent?
			}
		}
		return groupObj;
	}
}
