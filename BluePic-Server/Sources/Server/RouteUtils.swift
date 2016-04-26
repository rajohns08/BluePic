/**
* Copyright IBM Corporation 2016
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

import Foundation
import CouchDB
import Kitura
import KituraNet
import LoggerAPI
import Credentials
import SwiftyJSON

func parseImages(document: JSON) throws -> JSON {
  guard let rows = document["rows"].array else {
    throw ProcessingError.User("Invalid images document returned from Cloudant!")
  }

  let upperBound = (rows.count) - 1
  var images: [JSON] = []
  for index in 0...upperBound {
    var record = rows[index]["doc"]
    if index % 2 == 0 {
      massageImageRecord(&record)
      images.append(record)
    } else {
      var record = images[images.endIndex - 1]
      record["user"] = rows[index]["doc"]
    }
  }
  return constructDocument(document, records: images)
}

func parseImagesForUser(document: JSON) throws -> JSON {
  guard let rows = document["rows"].array else {
    throw ProcessingError.User("Invalid images document returned from Cloudant!")
  }

  var images: [JSON] = []
  for row in rows {
    var record = row["value"]
    massageImageRecord(&record)
    images.append(record)
  }
  return constructDocument(document, records: images)
}

func parseUsers(document: JSON) throws -> JSON {
  let users = try parseRecords(document)
  return constructDocument(document, records: users)
}

func getImageDocument(request: RouterRequest) throws -> JSONDictionary {
  guard let displayName = request.params["displayName"],
  let fileName = request.params["fileName"],
  let userId = request.params["userId"] else {
    throw ProcessingError.Image("Invalid image document!")
  }

  #if os(Linux)
  let ext = fileName.componentsSeparatedByString(".")[1].lowercased()
  #else
  let ext = fileName.componentsSeparated(by: ".")[1].lowercased()
  #endif

  guard let contentType = ContentType.contentTypeForExtension(ext) else {
    throw ProcessingError.Image("Invalid image document!")
  }

  #if os(Linux)
  let dateStr = NSDate().descriptionWithLocale(nil).bridge()
  let uploadedTs = dateStr.substringToIndex(10) + "T" + dateStr.substringWithRange(NSMakeRange(11, 8))
  let imageName = displayName.stringByReplacingOccurrencesOfString("%20", withString: " ")
  #else
  let dateStr = NSDate().description(withLocale: nil).bridge()
  let uploadedTs = dateStr.substring(to: 10) + "T" + dateStr.substring(with:NSMakeRange(11, 8))
  let imageName = displayName.replacingOccurrences(of: "%20", with: " ")
  #endif

  let imageDocument: JSONDictionary = ["contentType": contentType, "fileName": fileName, "userId": userId, "displayName": imageName, "uploadedTs": uploadedTs, "type": "image"]
  return imageDocument
}

func generateInternalError() -> NSError {
  return NSError(domain: BluePic.Domain, code: BluePic.Error.Internal.rawValue, userInfo: [NSLocalizedDescriptionKey: String(BluePic.Error.Internal)])
}

private func massageImageRecord(record: inout JSON) {
  let id = record["_id"].stringValue
  let fileName = record["fileName"].stringValue
  record["url"].stringValue = "http://\(database.connProperties.hostName):\(database.connProperties.port)/\(database.name)/\(id)/\(fileName)"
  record["length"].int = record["_attachments"]["jen.png"]["length"].int
  record.dictionaryObject?.removeValue(forKey: "userId")
  record.dictionaryObject?.removeValue(forKey: "_attachments")
}

private func parseRecords(document: JSON) throws -> [JSON] {
  guard let rows = document["rows"].array else {
    throw ProcessingError.User("Invalid document returned from Cloudant!")
  }

  var records: [JSON] = []
  for row in rows {
    let record = row["value"]
    records.append(record)
  }
  return records
}

private func constructDocument(document: JSON, records: [JSON]) -> JSON {
  var jsonDocument = JSON([:])
  //jsonDocument["offset"] = document["offset"]
  jsonDocument["number_of_records"].int = records.count
  jsonDocument["records"] = JSON(records)
  return jsonDocument
}
