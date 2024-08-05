import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lion12/view/community/post.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'detail.dart';

class PostPage extends StatefulWidget {
  const PostPage({super.key});

  @override
  _PostPageState createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> posts = [];
  String? nickname;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchNicknameAndPosts();
  }

  Future<void> fetchNicknameAndPosts() async {
    await fetchNickname();
    await fetchPosts();
  }

  Future<void> fetchNickname() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    if (token == null) {
      print('토큰을 찾을 수 없습니다.');
      return;
    }

    final response = await http.get(
      Uri.parse('http://13.125.226.133/api/mypage'), // 사용자 정보 가져오는 API 엔드포인트
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        nickname = data['nickname']; // 닉네임 설정
      });
    } else {
      print('사용자 정보를 불러오는 데 실패했습니다: ${response.statusCode}');
    }
  }

  Future<void> fetchPosts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    if (token == null) {
      print('토큰을 찾을 수 없습니다.');
      return;
    }

    const url = 'http://13.125.226.133/onsil/board/list'; // 실제 API URL로 변경 필요
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      print('API 응답 데이터: $data');
      setState(() {
        posts = (data['content'] as List).map((post) {
          print('게시글 데이터: $post');
          return {
            'postId': post['postId'] ?? 0, // postId로 변경
            'username': post['writerNickname'] ?? 'Unknown', // writerNickname으로 변경
            'likes': post['recommend'] ?? 0,
            'title': post['title'] ?? 'No Title',
            'image': post['image'] ?? '',
            'category': _getFormattedCategory(post['category'] ?? ''),
            'liked': post['liked'] ?? false,
            'date': post['date'] ?? '',
          };
        }).toList();
      });
    } else {
      print('게시글을 불러오는 데 실패했습니다: ${response.statusCode}');
      throw Exception('게시글을 불러오는 데 실패했습니다');
    }
  }

  String _getFormattedCategory(String category) {
    switch (category) {
      case 'SAN':
        return '산책';
      case 'JIL':
        return '질병';
      case 'CHIN':
        return '친목';
      default:
        return category;
    }
  }

  Future<void> _toggleLike(int index) async {
    final postId = posts[index]['postId']; // postId 사용
    final url = posts[index]['liked']
        ? 'http://13.125.226.133/onsil/board/recommend/down/$postId'
        : 'http://13.125.226.133/onsil/board/recommend/up/$postId';

    print('호출할 URL: $url');

    setState(() {
      posts[index]['liked'] = !posts[index]['liked'];
      if (posts[index]['liked']) {
        posts[index]['likes'] += 1;
      } else {
        posts[index]['likes'] -= 1;
      }
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        print('좋아요 상태가 성공적으로 업데이트되었습니다.');
      } else {
        print('좋아요 상태 업데이트 실패: ${response.statusCode}');
        print('응답 본문: ${response.body}');

        setState(() {
          posts[index]['liked'] = !posts[index]['liked'];
          if (posts[index]['liked']) {
            posts[index]['likes'] += 1;
          } else {
            posts[index]['likes'] -= 1;
          }
        });
        throw Exception('좋아요 상태 업데이트 실패: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('오류 발생: $e');

      setState(() {
        posts[index]['liked'] = !posts[index]['liked'];
        if (posts[index]['liked']) {
          posts[index]['likes'] += 1;
        } else {
          posts[index]['likes'] -= 1;
        }
      });
    }
  }

  List<Map<String, dynamic>> getSortedPosts(String type) {
    if (type == 'latest') {
      List<Map<String, dynamic>> sortedPosts = List.from(posts);
      sortedPosts.sort((a, b) => b['date'].compareTo(a['date']));
      return sortedPosts;
    } else if (type == 'popular') {
      List<Map<String, dynamic>> sortedPosts = List.from(posts);
      sortedPosts.sort((a, b) => (b['likes'] ?? 0).compareTo(a['likes'] ?? 0));
      return sortedPosts;
    }
    return posts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
              tabs: [
                Tab(text: '최신글'),
                Tab(text: '인기글'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                buildPostList(getSortedPosts('latest')),
                buildPostList(getSortedPosts('popular')),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: GestureDetector(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => WritePostPage()));
        },
        child: Image.asset('assets/img/add.png'),
      ),
    );
  }

  Widget buildPostList(List<Map<String, dynamic>> posts) {
    return ListView.separated(
      itemCount: posts.length,
      separatorBuilder: (context, index) => Divider(
        color: Colors.grey[300], // 구분선 색상
        thickness: 1.0, // 구분선 두께
      ),
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailPage(postId: posts[index]['postId']), // postId 사용
              ),
            );
          },
          child: Container(
            color: Colors.grey[100], // 게시글 배경색을 회색으로 설정
            child: Card(
              margin: EdgeInsets.zero, // Card 위젯의 외부 여백 제거
              color: Colors.white, // Card 배경색 흰색으로 설정
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Image.asset(
                          'assets/img/man.png',
                        ),
                      ),
                      title: Text(posts[index]['username']),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 제목이 왼쪽에 오도록 설정
                          Expanded(
                            child: Text(
                              posts[index]['title'],
                              style: TextStyle(
                                fontSize: 16.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (posts[index]['image'].isNotEmpty) // 이미지가 있는 경우
                            Padding(
                              padding: const EdgeInsets.only(left: 12.0),
                              child: Image.network(
                                posts[index]['image'],
                                width: 100, // 이미지 너비 조정
                                height: 100, // 이미지 높이 조정
                                fit: BoxFit.cover, // 이미지 잘림 방지
                              ),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Image.asset(
                                'assets/img/heart.png',
                                width: 20,
                                height: 20,
                                color: posts[index]['liked'] ? Colors.red : Colors.black,
                              ),
                              onPressed: () {
                                _toggleLike(index);
                              },
                            ),
                            SizedBox(width: 8), // 아이콘과 숫자 사이의 간격 조정
                            Text('${posts[index]['likes']}'),
                          ],
                        ),
                        if (posts[index]['category'].isNotEmpty) // 카테고리가 있는 경우에만 표시
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Chip(
                              label: Text(posts[index]['category']),
                              backgroundColor: Colors.blue.shade100,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
//community.dart 코드