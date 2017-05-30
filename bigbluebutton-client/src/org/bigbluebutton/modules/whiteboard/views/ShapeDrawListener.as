/**
 * BigBlueButton open source conferencing system - http://www.bigbluebutton.org/
 * 
 * Copyright (c) 2012 BigBlueButton Inc. and by respective authors (see below).
 *
 * This program is free software; you can redistribute it and/or modify it under the
 * terms of the GNU Lesser General Public License as published by the Free Software
 * Foundation; either version 3.0 of the License, or (at your option) any later
 * version.
 * 
 * BigBlueButton is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
 * PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License along
 * with BigBlueButton; if not, see <http://www.gnu.org/licenses/>.
 *
 */
package org.bigbluebutton.modules.whiteboard.views
{
  import flash.geom.Point;
  
  import org.bigbluebutton.modules.whiteboard.business.shapes.DrawAnnotation;
  import org.bigbluebutton.modules.whiteboard.business.shapes.ShapeFactory;
  import org.bigbluebutton.modules.whiteboard.business.shapes.WhiteboardConstants;
  import org.bigbluebutton.modules.whiteboard.models.Annotation;
  import org.bigbluebutton.modules.whiteboard.models.AnnotationStatus;
  import org.bigbluebutton.modules.whiteboard.models.AnnotationType;
  import org.bigbluebutton.modules.whiteboard.views.models.WhiteboardTool;
  
  public class ShapeDrawListener implements IDrawListener
  {
    private var _drawStatus:String = AnnotationStatus.DRAW_START;
    private var _isDrawing:Boolean = false; 
    private var _segment:Array = new Array();
    private var _wbCanvas:WhiteboardCanvas;
    private var _shapeFactory:ShapeFactory;
    private var _idGenerator:AnnotationIDGenerator;
    private var _curID:String;
    private var _wbId:String = null;
        
    public function ShapeDrawListener(idGenerator:AnnotationIDGenerator, 
                                       wbCanvas:WhiteboardCanvas, 
                                       shapeFactory:ShapeFactory) {
      _idGenerator = idGenerator;
      _wbCanvas = wbCanvas;
      _shapeFactory = shapeFactory;
    }
    
    public function onMouseDown(mouseX:Number, mouseY:Number, tool:WhiteboardTool, wbId:String):void {
      if (tool.toolType == AnnotationType.RECTANGLE || 
          tool.toolType == AnnotationType.TRIANGLE || 
          tool.toolType == AnnotationType.ELLIPSE || 
          tool.toolType == AnnotationType.LINE) {
        if (_isDrawing) { //means we missed the UP
          onMouseUp(mouseX, mouseY, tool);
          return;
        }
        
        _isDrawing = true;
        _drawStatus = AnnotationStatus.DRAW_START;
        
        _wbId = wbId;
        
        // Generate a shape id so we can match the mouse down and up events. Then we can
        // remove the specific shape when a mouse up occurs.
        _curID = _idGenerator.generateID();
        
//        LogUtil.debug("* START count = [" + objCount + "] id=[" + _curID + "]"); 
        
        //normalize points as we get them to avoid shape drift
        var np:Point = _shapeFactory.normalizePoint(mouseX, mouseY);
        
        _segment = new Array();
        _segment.push(np.x);
        _segment.push(np.y);
      } 
    }

    public function onMouseMove(mouseX:Number, mouseY:Number, tool:WhiteboardTool):void {
      if (tool.graphicType == WhiteboardConstants.TYPE_SHAPE) {
        if (_isDrawing){
          
          //normalize points as we get them to avoid shape drift
          var np:Point = _shapeFactory.normalizePoint(mouseX, mouseY);
          
          var statusToSend:String = (_segment.length == 2 ? AnnotationStatus.DRAW_START : AnnotationStatus.DRAW_UPDATE);
          
          _segment[2] = np.x;
          _segment[3] = np.y;
          
          sendShapeToServer(statusToSend, tool);
        }
      }
    }

    public function onMouseUp(mouseX:Number, mouseY:Number, tool:WhiteboardTool):void {
      if (tool.graphicType == WhiteboardConstants.TYPE_SHAPE) {
        if (_isDrawing) {
          /**
            * Check if we are drawing because when resizing the window, it generates
            * a mouseUp event at the end of resize. We don't want to dispatch another
            * shape to the viewers.
            */
          _isDrawing = false;
          
          //normalize points as we get them to avoid shape drift
          var np:Point = _shapeFactory.normalizePoint(mouseX, mouseY);
          
          _segment[2] = np.x;
          _segment[3] = np.y;
          
          sendShapeToServer(AnnotationStatus.DRAW_END, tool);
        } /* (_isDrawing) */                
      }
    }
    
    private function sendShapeToServer(status:String, tool:WhiteboardTool):void {
      if (_segment.length > 2) {
        // LogUtil.debug("SEGMENT too short");
        return;
      }
                       
      var dobj:DrawAnnotation = _shapeFactory.createDrawObject(tool.toolType, _segment, tool.drawColor, tool.thickness, 
                                                  tool.fillOn, tool.fillColor, tool.transparencyOn);
      
      dobj.status = status;
      dobj.id = _curID;
      
      var an:Annotation = dobj.createAnnotation(_wbId);
      
      if (an != null) {
        _wbCanvas.sendGraphicToServer(an);
      }
    }
  }
}