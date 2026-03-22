import '../core/constants/x_api_constants.dart';

class XTimelineRequestBuilder {
  const XTimelineRequestBuilder();

  Map<String, dynamic> build({String? cursor}) {
    return {
      'max_results': XApiConstants.maxResults,
      'expansions': XApiConstants.expansions.join(','),
      'tweet.fields': XApiConstants.tweetFields.join(','),
      'media.fields': XApiConstants.mediaFields.join(','),
      'user.fields': XApiConstants.userFields.join(','),
      'exclude': XApiConstants.defaultExclude.join(','),
      if ((cursor ?? '').isNotEmpty) 'pagination_token': cursor,
    };
  }
}
