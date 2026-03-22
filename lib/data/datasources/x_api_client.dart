import 'package:dio/dio.dart';

import '../../core/constants/x_api_constants.dart';
import '../../core/errors/x_api_exception.dart';
import '../../data/models/x_api_timeline_response.dart';
import '../../services/x_timeline_request_builder.dart';

class XApiClient {
  XApiClient({
    required Dio dio,
    required XTimelineRequestBuilder requestBuilder,
  }) : _dio = dio,
       _requestBuilder = requestBuilder;

  final Dio _dio;
  final XTimelineRequestBuilder _requestBuilder;

  Future<XApiTimelineResponse> fetchHomeTimeline({
    required String accessToken,
    required String userId,
    String? cursor,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        XApiConstants.reverseChronologicalTimelinePath.replaceFirst(
          '{id}',
          userId,
        ),
        queryParameters: _requestBuilder.build(cursor: cursor),
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      final body = response.data;
      if (body == null) {
        throw XApiException.invalidResponse('Response body was null');
      }

      final timelineResponse = XApiTimelineResponse.fromJson(body);
      if (timelineResponse.errors.isNotEmpty && timelineResponse.data.isEmpty) {
        final firstError = timelineResponse.errors.first;
        throw XApiException.apiError(
          message: firstError.detail.isEmpty
              ? firstError.title
              : firstError.detail,
          statusCode: firstError.status ?? response.statusCode,
          details: body,
        );
      }

      return timelineResponse;
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  XApiException _mapDioException(DioException error) {
    final statusCode = error.response?.statusCode;
    final details = error.response?.data ?? error.message;

    switch (statusCode) {
      case 401:
        return XApiException.unauthorized(details);
      case 403:
        return XApiException.forbidden(details);
      case 429:
        return XApiException.rateLimited(details);
      default:
        return XApiException.apiError(
          message: 'Failed to fetch X timeline.',
          statusCode: statusCode,
          details: details,
        );
    }
  }
}
